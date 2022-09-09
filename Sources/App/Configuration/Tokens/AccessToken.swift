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

	enum CodingKeys: String, CodingKey {
		case name, scopes, organizations
		case issuer = "iss"
		case subject = "sub"
		case audience = "aud"
		case expiration = "exp"
		case issued = "iat"
	}

	enum BackCompatCodingKeys: String, CodingKey {
		case issuer, subject, audience, expiration, issued
	}

	// Always encode with the new format (though ticketing doesn't do encode)
	init(from decoder: Decoder) throws {
		let newContainer = try decoder.container(keyedBy: CodingKeys.self)
		self.name = try newContainer.decode(String.self, forKey: .name)
		self.scopes = try newContainer.decode([String].self, forKey: .scopes)
		self.organizations = try newContainer.decode([NamedID].self, forKey: .organizations)

		if let issuer = try newContainer.decodeIfPresent(IssuerClaim.self, forKey: .issuer) {
			// New keys are good, use those
			self.issuer = issuer
			self.subject = try newContainer.decode(SubjectClaim.self, forKey: .subject)
			self.audience = try newContainer.decode(AudienceClaim.self, forKey: .audience)
			self.expiration = try newContainer.decode(ExpirationClaim.self, forKey: .expiration)
			self.issued = try newContainer.decode(IssuedAtClaim.self, forKey: .issued)
		} else {
			// Use compat keys.
			let oldContainer = try decoder.container(keyedBy: BackCompatCodingKeys.self)
			self.issuer = try oldContainer.decode(IssuerClaim.self, forKey: .issuer)
			self.subject = try oldContainer.decode(SubjectClaim.self, forKey: .subject)
			self.audience = try oldContainer.decode(AudienceClaim.self, forKey: .audience)
			self.expiration = try oldContainer.decode(ExpirationClaim.self, forKey: .expiration)
			self.issued = try oldContainer.decode(IssuedAtClaim.self, forKey: .issued)
		}
	}
}

/// Helper struct to have content with a name and an ID.
struct NamedID: Codable, Identifiable {
	/// The name for the object this describes.
	var name: String
	/// The ID of the object this describes.
	var id: UUID
}
