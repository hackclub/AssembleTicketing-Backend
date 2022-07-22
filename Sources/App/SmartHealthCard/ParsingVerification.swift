import Foundation
import SWCompression
import JWTKit

#if canImport(FoundationNetworking)
import FoundationNetworking

// NOTE: FoundationNetworking doesn't natively support asynchronous URLSession methods.
extension URLSession {
	func data(for request: URLRequest) async throws -> (data: Data, response: URLResponse) {
		return try await withCheckedThrowingContinuation({ continuation in
			self.dataTask(with: request) { data, response, error in
				if let error = error {
					continuation.resume(throwing: error)
					return
				}

				guard let data = data, let response = response else {
					// Not strictly true, but this should never be called anyways. In the event that it is, Amino should not crash. So we lie to the rest of the app.
					continuation.resume(throwing: URLError(.cancelled))
					return
				}


				continuation.resume(returning: (data, response))
			}
		})
	}

	func data(from url: URL) async throws -> (data: Data, response: URLResponse) {
		return try await withCheckedThrowingContinuation({ continuation in
			self.dataTask(with: url) { data, response, error in
				if let error = error {
					continuation.resume(throwing: error)
					return
				}

				guard let data = data, let response = response else {
					// Not strictly true, but this should never be called anyways. In the event that it is, Amino should not crash. So we lie to the rest of the app.
					continuation.resume(throwing: URLError(.cancelled))
					return
				}


				continuation.resume(returning: (data, response))
			}
		})
	}
}
#endif

extension SmartHealthCard {
	/// A function that verifies a series of SMART Health Card chunks.
	///
	static func verify(qrChunks: [String]) async throws -> (issuerName: String, payload: Payload) {
		var jwsChunks = try qrChunks.map { chunk -> (chunkNumber: Int, chunk: String) in
			// Shadow it so we can use the damned thing.
			var chunk = chunk

			// Remove the prefix.
			let prefix = chunk.removeFirst(5)

			let chunkValues = chunk.split(separator: "/")

			guard chunkValues.count == 3 else {
				throw VerificationError.notChunked
			}

			guard let chunkNumber = Int(chunkValues[0]), let totalChunks = Int(chunkValues[1]) else {
				throw VerificationError.invalidChunkHeaders
			}

			guard qrChunks.count == totalChunks else {
				throw VerificationError.chunksRequired
			}

			guard prefix == "shc:/" else {
				throw VerificationError.missingQRScheme
			}

			let chunkBody = String(chunkValues[2])

			let chunkString = try decodeIgnoringHeader(body: chunkBody)

			return (chunkNumber: chunkNumber, chunk: chunkString)
		}

		jwsChunks.sort { lhs, rhs in
			lhs.chunkNumber < rhs.chunkNumber
		}

		let orderedChunks = jwsChunks.map { (chunkNumber: Int, chunk: String) in
			return chunk
		}

		let jws = orderedChunks.joined(separator: "")

		return try await verify(jws: jws)
	}

	/// A function that verifies a SMART Health Card from a QR Code's representation.
	///
	/// - Parameters:
	///   - qr: The string that you get from decoding a SMART Health Card QR code.
	public static func verify(qr: String) async throws -> (issuerName: String, payload: Payload) {
		// Shadow the thing so we can mutate it
		var qr = qr
		// Remove the prefix.
		let prefix = qr.removeFirst(5)
		guard prefix == "shc:/" else {
			throw VerificationError.missingQRScheme
		}

		let chunkValues = qr.split(separator: "/")

		guard chunkValues.count == 1 else {
			throw VerificationError.chunksRequired
		}

		let jws = try decodeIgnoringHeader(body: qr)

		return try await verify(jws: jws)
	}

	/// A function that decodes a SMART Health Card body portion or chunk.
	///
	/// - Parameters:
	///   - body: The string that you get from decoding a SMART Health Card QR code after stripping the headers.
	private static func decodeIgnoringHeader(body: String) throws -> String {
		// Split the numbers into 2 digit chunks
		let split = body.split(every: 2)

		let characters = try split.map { substring -> Character in
			guard let number = UInt8(substring) else {
				throw VerificationError.failedQRNumberConversion
			}
			return qrEncodedCharacter(int: number)
		}

		let string = String(characters)
		return string
	}

	/// A function that verifies a SMART Health Card from a JWS representation.
	///
	/// - Parameters:
	///   - jws: A string containing the JSON Web Signature format version of the health card.
	public static func verify(jws: String) async throws -> (issuerName: String, payload: Payload) {
		print("verify jws called")

		let (issuer, kid, name) = try getInfo(from: jws)

		print("got jws data")

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		let (jwksData, _) = try await URLSession.shared.data(from: issuer.appendingPathComponent(".well-known/jwks.json"))
		print("got jwks")
		let jwks = try decoder.decode(JWKS.self, from: jwksData)

		print("decoded jwks")

		let signers = JWTSigners()
		try signers.use(jwks: jwks)

		print("using jwks")

		let payload = try signers.verify(jws, as: Payload.self)

		print("verified key")

		if let rid = payload.verifiableCredential.rid {
			let (revocationData, _) = try await URLSession.shared.data(from: issuer.appendingPathComponent(".well-known/crl/\(kid).json"))


			print("got revocation list")

			let revocations = try decoder.decode(RevocationData.self, from: revocationData)


			print("decoded revocation list")

			let revocationList = revocations.rids.map { string -> (rid: String, invalidateAllBefore: Date) in
				let strings = string.split(separator: ".")
				var date: Date
				if strings.count > 1, let epochTime = Double(strings[1]) {
					date = Date(timeIntervalSince1970: epochTime)
				} else {
					date = Date()
				}

				return (String(strings[0]), date)
			}

			print("converted revocation list")

			let firstRevocation = revocationList.first { (listedRID: String, invalidateAllBefore: Date) in
				guard rid != listedRID else {
					return true
				}

				guard payload.notBefore <= invalidateAllBefore else {
					return true
				}

				return false
			}

			print("got first revocation")

			guard firstRevocation == nil else {
				throw VerificationError.revoked
			}
		}
		print("about to return")

		return (name, payload)
	}

	private static func getInfo(from jws: String) throws -> (issuer: URL, keyID: String, issuerName: String) {
		let splitJWS = jws.split(separator: ".")

		let splitJWSData = try splitJWS.map { jwsComponent -> Data in
			guard let data = Data(base64URLEncoded: String(jwsComponent)) else {
				throw VerificationError.invalidJWS
			}
			return data
		}

		let bodyData = try Deflate.decompress(data: splitJWSData[1])

		let decoder = JSONDecoder()
		let headers = try decoder.decode(KeyIDHelper.self, from: splitJWSData[0])
		let body = try decoder.decode(Payload.self, from: bodyData)

		guard let lookupIssuer = issuers[body.issuer] else {
			throw VerificationError.invalidProvider
		}

		let issuerName = lookupIssuer.name

		return (body.issuer, headers.kid, issuerName)
	}

	/// A struct representing the structure of a Certificate Revocation List.
	struct RevocationData: Codable {
		/// The key on which things have been revoked.
		var kid: String
		/// The method by which things have been revoked.
		var method: String
		/// The `rids` that have been revoked, if any.
		var rids: [String]
	}

	/// A small helper struct to decode the key ID from the headers of a JWS.
	struct KeyIDHelper: Codable {
		/// The key ID of the JWS.
		var kid: String
	}

	/// A function to convert from the SMART Health Card numerical format to a Swift Character.
	/// - Parameters:
	///   - int: A `UInt8` containing the health card's formatted 2-digit representation of the character.
	private static func qrEncodedCharacter(int: UInt8) -> Character {
		let convertedNumber = int + 45

		return Character(.init(convertedNumber))
	}
}
