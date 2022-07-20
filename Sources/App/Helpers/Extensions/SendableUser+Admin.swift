import Foundation

extension SendableUser {
	var isAssembleAdmin: Bool {
		self.organizations.contains { orgRole in
			orgRole.organizationID == assembleOrgID &&
			orgRole.roles.contains("admin")
		}
	}
}
