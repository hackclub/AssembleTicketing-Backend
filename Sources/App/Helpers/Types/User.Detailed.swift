import Foundation
import Vapor


// TODO: Rename this to something that makes sense
extension User {
	/// The structure of the data that the ID service gives us back when we request more user info than the token provides.
	struct Detailed: Content {
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
}

extension User.Detailed {
	func isAssembleAdmin(on orgID: UUID) -> Bool {
		self.organizations.contains { orgRole in
			orgRole.organizationID == orgID &&
			orgRole.roles.contains("admin")
		}
	}
}
