import Foundation
import JWTKit

extension SmartHealthCard {
	public struct Payload: Codable, JWTPayload {
		public func verify(using signer: JWTSigner) throws { return }

		enum CodingKeys: String, CodingKey {
			case issuer = "iss"
			case notBefore = "nbf"
			case verifiableCredential = "vc"
		}

		/// The URL of the issuer.
		///
		/// Note: You can append `/.well-known/jwks.json` to get the JWKS of the public key used to issue this.
		public var issuer: URL

		/// A date, before which the token is not valid.
		public var notBefore: Date

		/// A Verifiable Credential claim.
		public var verifiableCredential: VerifiableCredential
	}
}

