import JWT
import Vapor
import Foundation

struct AccessToken: JWTPayload, Authenticatable {
	func verify(using signer: JWTSigner) throws {
		try self.expiration.verifyNotExpired()
		// TODO: Remove this compatibility check
		do {
			// TODO: Make this configurable
			try self.audience.verifyIntendedAudience(includes: "https://api.ticketing.assemble.hackclub.com/")
		} catch {
			try self.audience.verifyIntendedAudience(includes: "https://indocs.api.allotrope.dev/")
		}
		// TODO: Make tokens actually require an issuer of the configured ID URL
	}

	var name: String
	// Standard Stuff
	var issuer: IssuerClaim
	var subject: SubjectClaim
	var audience: AudienceClaim
	var expiration: ExpirationClaim
	var issued: IssuedAtClaim
	// Auth Stuff
	/// The scopes the token is authorized for.
	var scopes: [String]
	/// The organizations the token is authorized to modify.
	var organizations: [NamedID]
}

/// Helper struct to have content with a name and an ID.
struct NamedID: Codable, Identifiable {
	/// The name for the object this describes.
	var name: String
	/// The ID of the object this describes.
	var id: UUID
}
