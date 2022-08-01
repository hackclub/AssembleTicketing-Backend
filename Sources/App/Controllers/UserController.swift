import Vapor
import JWT
import Fluent

struct UserController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let users = routes.grouped("users")
		users.get(use: oldMe)
		users.get("small", use: me)
		let admin = users
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")
		admin.get("index", use: adminIndex)
		admin.get(":userID", use: adminGet)
		admin.get(["filtered", "status", ":status"], use: getFilteredStatus)
	}

	func getFilteredStatus(req: Request) async throws -> [User.Response] {
		guard let statusString = req.parameters.get("status"), let status = User.VerificationStatus(rawValue: statusString) else {
			throw Abort(.badRequest, reason: "Invalid status.")
		}

		let filteredUsers = try await User
			.query(on: req.db)
			.filter(\.$vaccinationStatus == status)
			.all()

		return try await filteredUsers.concurrentMap { user in
			return try await user.getResponse(on: req.db)
		}
	}

	func adminGet(req: Request) async throws -> User.Response {
		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}
		return try await user.getResponse(on: req.db)
	}

	func adminIndex(req: Request) async throws -> [User.Response] {
		return try await User.query(on: req.db).all().concurrentMap({ try await $0.getResponse(on: req.db) })
	}

	/// Get or create the user (if it doesn't exist already), returning the vaccination card if available.
	///
	/// When available, use new `me`, since it doesn't spuriously get the vaccination info.
	@available(*, deprecated, renamed: "me")
	func oldMe(req: Request) async throws -> User.Response {
		let token = try req.auth.require(AccessToken.self)

		let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db)

		if let user = user {
			// Note: For compatibility. When nobody's using the old stuff, remove this from user.
			try await user.$vaccinationData.load(on: req.db)

			return try await user.getResponse(on: req.db)
		} else {
			let sendable = try await req.getUserDetails()

			guard sendable.organizations.contains(where: { orgRole in
				orgRole.organizationID == req.ticketingConfiguration.organizationID
			}) else {
				throw Abort(.forbidden, reason: "You're not in the configured organization. Check with your hackathon's organizers.")
			}

			let user = User(id: sendable.id, name: sendable.name, email: sendable.email, vaccinationStatus: .noData)

			try await user.save(on: req.db)

			return try await user.getResponse(on: req.db)
		}
	}

	func me(req: Request) async throws -> User.Response {
		let token = try req.auth.require(AccessToken.self)

		let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db)

		if let user = user {
			return try await user.getResponse(on: req.db)
		} else {
			let sendable = try await req.getUserDetails()

			guard sendable.organizations.contains(where: { orgRole in
				orgRole.organizationID == req.ticketingConfiguration.organizationID
			}) else {
				throw Abort(.forbidden, reason: "You're not in the Assemble org.")
			}

			let user = User(id: sendable.id, name: sendable.name, email: sendable.email, vaccinationStatus: .noData)

			try await user.save(on: req.db)

			return try await user.getResponse(on: req.db)
		}
	}
}


