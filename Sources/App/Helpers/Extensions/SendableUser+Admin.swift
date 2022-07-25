import Foundation

extension SendableUser {
	func isAssembleAdmin(on orgID: UUID) -> Bool {
		self.organizations.contains { orgRole in
			orgRole.organizationID == orgID &&
			orgRole.roles.contains("admin")
		}
	}
}
