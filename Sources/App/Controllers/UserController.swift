import Vapor
import JWT

struct UserController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let users = routes.grouped("users")
		users.get(use: me)
	}

	/// Get or create the user (if it doesn't exist already).
	func me(req: Request) async throws -> User {
		let token = try req.auth.require(AccessToken.self)

		let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db)

		guard let authorizationHeader = req.headers.bearerAuthorization else {
			throw Abort(.badRequest, reason: "Missing authorization header.")
		}

		if let user = user {
			return user
		} else {
			let userRequest = try await req.client.get("https://api.allotrope.id/users/me", headers: .init([
				("Authorization", "Bearer \(authorizationHeader.token)")
			]))

			let sendable = try userRequest.content.decode(SendableUser.self)

			guard sendable.organizations.contains(where: { orgRole in
				// TODO: Make this configurable
				orgRole.organizationID == UUID(uuidString: "8ceeeff2-276d-4e73-93a4-eaa33bd43677")!
			}) else {
				throw Abort(.forbidden, reason: "You're not in the Assemble org.")
			}

			let user = User(id: sendable.id, name: sendable.name, email: sendable.email, vaccinationStatus: .noData)

			try await user.save(on: req.db)

			return user
		}
	}
}

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
