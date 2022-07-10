import Foundation
import SWCompression
import JWTKit

extension SmartHealthCard {
	/// A function that verifies a series of SMART Health Card chunks.
	///
	static func verify(qrChunks: [String]) async throws -> Payload {
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
	public static func verify(qr: String) async throws -> Payload {
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
	public static func verify(jws: String) async throws -> Payload {
		let issuer = try getIssuer(from: jws)

		let (jwksData, _) = try await URLSession.shared.data(from: issuer.appendingPathComponent(".well-known/jwks.json"))

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .secondsSince1970
		let jwks = try decoder.decode(JWKS.self, from: jwksData)

		let signers = JWTSigners()
		try signers.use(jwks: jwks)

		let payload = try signers.verify(jws, as: Payload.self)

		return payload
	}

	private static func getIssuer(from jws: String) throws -> URL {
		let splitJWS = jws.split(separator: ".")

		let splitJWSData = try splitJWS.map { jwsComponent -> Data in
			guard let data = Data(base64URLEncoded: String(jwsComponent)) else {
				throw VerificationError.invalidJWS
			}
			return data
		}

		let bodyData = try Deflate.decompress(data: splitJWSData[1])
		let decoder = JSONDecoder()
		let body = try decoder.decode(Payload.self, from: bodyData)

		return body.issuer
	}

	/// A function to convert from the SMART Health Card numerical format to a Swift Character.
	/// - Parameters:
	///   - int: A `UInt8` containing the health card's formatted 2-digit representation of the character.
	private static func qrEncodedCharacter(int: UInt8) -> Character {
		let convertedNumber = int + 45

		return Character(.init(convertedNumber))
	}
}
