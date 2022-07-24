import Vapor
import JWT

struct UserController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let users = routes.grouped("users")
		users.get(use: me)
		users.get("small", use: me)
		let admin = users
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")
		admin.get("index", use: adminIndex)
	}

	func adminIndex(req: Request) async throws -> [User.Response] {
		return try await User.query(on: req.db).all().map({ try $0.response() })
	}

	/// Get or create the user (if it doesn't exist already).
	func me(req: Request) async throws -> User.Response {
		let token = try req.auth.require(AccessToken.self)

		let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db)

		if let user = user {
			try await user.$vaccinationData.load(on: req.db)

			return try user.response()
		} else {
			let sendable = try await req.getUserDetails()

			guard sendable.organizations.contains(where: { orgRole in
				orgRole.organizationID == assembleOrgID
			}) else {
				throw Abort(.forbidden, reason: "You're not in the Assemble org.")
			}

			let user = User(id: sendable.id, name: sendable.name, email: sendable.email, vaccinationStatus: .noData)

			try await user.save(on: req.db)

			return try user.response()
		}
	}
}


