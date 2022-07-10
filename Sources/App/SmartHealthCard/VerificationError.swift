import Foundation

extension SmartHealthCard {
	public enum VerificationError: Error {
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
	}
}
