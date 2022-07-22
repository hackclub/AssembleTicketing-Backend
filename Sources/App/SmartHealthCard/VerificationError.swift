import Foundation
import Vapor

extension SmartHealthCard {
	public enum VerificationError: String, Error, AbortError {
		public var status: NIOHTTP1.HTTPResponseStatus {
			.badRequest
		}

		public var reason: String {
			friendlyName
		}
		
		/// More chunks than the ones provided are required.
		case chunksRequired
		/// A chunk was provided without chunk headers. Use the traditional single-qr verifier for non-chunked data.
		case notChunked
		/// The headers of a chunk weren't valid.
		case invalidChunkHeaders
		/// The required scheme in some QR code data was missing.
		case missingQRScheme
		/// Conversion from the numeric QR code format to the JWS format failed.
		case failedQRNumberConversion
		/// The data provided wasn't a valid JWS.
		case invalidJWS
		/// The card was revoked by the provider.
		case revoked
		/// The card wasn't from an approved provider.
		case invalidProvider

		var friendlyName: String {
			switch self {
				case .chunksRequired:
					return "We need more QR chunks than the ones provided."
				case .notChunked:
					return "A non-chunked QR code was submitted through the chunked header."
				case .invalidChunkHeaders:
					return "The headers of a chunk weren't valid."
				case .missingQRScheme:
					return "The required scheme in the QR data was missing."
				case .failedQRNumberConversion:
					return "Conversion from the numeric QR format failed."
				case .invalidJWS:
					return "The data provided wasn't a valid SMART Health Card."
				case .revoked:
					return "Your health provider revoked this card."
				case .invalidProvider:
					return "This SMART Health Card wasn't issued by a valid provider."
			}
		}
	}
}
