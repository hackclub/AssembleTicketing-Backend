import Foundation
import Vapor
import SWCompression
import JWTKit

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension SmartHealthCard {
	/// A function that verifies a series of SMART Health Card chunks.
	///
	static func verify(qrChunks: [String], with req: Request) async throws -> (issuerName: String, payload: Payload) {
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

		return try await verify(jws: jws, with: req)
	}

	/// A function that verifies a SMART Health Card from a QR Code's representation.
	///
	/// - Parameters:
	///   - qr: The string that you get from decoding a SMART Health Card QR code.
	public static func verify(qr: String, with req: Request) async throws -> (issuerName: String, payload: Payload) {
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

		return try await verify(jws: jws, with: req)
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
	public static func verify(jws: String, with req: Request) async throws -> (issuerName: String, payload: Payload) {
		
		req.logger.log(level: .debug, "verify jws called")

		let (issuer, kid, name) = try getInfo(from: jws, with: req.healthCardConfig.issuers)

		req.logger.log(level: .debug, "got jws data")

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970

		let clientResponse = try await req.client.get(URI(stringLiteral: issuer.appendingPathComponent(".well-known/jwks.json").absoluteString))

		req.logger.log(level: .debug, "got jwks response")

		let jwks = try clientResponse.content.decode(JWKS.self)

		req.logger.log(level: .debug, "decoded jwks")

		let signers = JWTSigners()
		try signers.use(jwks: jwks)

		req.logger.log(level: .debug, "using jwks")

		let payload = try signers.verify(jws, as: Payload.self)

		req.logger.log(level: .debug, "verified key")

		if let rid = payload.verifiableCredential.rid {

			let clientResponse = try await req.client.get(URI(stringLiteral: issuer.appendingPathComponent(".well-known/crl/\(kid).json").absoluteString))

			req.logger.log(level: .debug, "got revocations response")

			let revocations = try clientResponse.content.decode(RevocationData.self)

			req.logger.log(level: .debug, "decoded revocation list")

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

			req.logger.log(level: .debug, "converted revocation list")

			let firstRevocation = revocationList.first { (listedRID: String, invalidateAllBefore: Date) in
				guard rid != listedRID else {
					return true
				}

				guard payload.notBefore <= invalidateAllBefore else {
					return true
				}

				return false
			}

			req.logger.log(level: .debug, "got first revocation")

			guard firstRevocation == nil else {
				throw VerificationError.revoked
			}
		}
		req.logger.log(level: .debug, "about to return")

		return (name, payload)
	}

	private static func getInfo(from jws: String, with issuers: Issuers) throws -> (issuer: URL, keyID: String, issuerName: String) {
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

		guard let lookupIssuer = issuers.value[body.issuer] else {
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
