import Foundation
import Vapor

struct SendableUser: Content {
	var id: UUID?
	var name: String
	var email: String
	var roles: [String]
	/// The organizations the user's in, with the roles as the value.
	var organizations: [OrgRole]

	struct OrgRole: Codable {
		var organizationID: UUID
		var roles: [String]
	}
}

