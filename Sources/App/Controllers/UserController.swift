import Vapor
import JWT
import Fluent

struct UserController: Controller {
	func getExistingModel(for user: User, on db: FluentKit.Database) async throws -> User? {
		return user
	}

	typealias ObjectType = User

	func boot(routes: RoutesBuilder) throws {
		let users = routes.grouped("users")
		users.get(use: me)
		let admin = users
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")
		admin.get("index", use: adminIndex)
		admin.get(":userID", use: adminGet)
		admin.get(["filtered", "vaccination", ":status"], use: filterVaccinationStatus)
		admin.get(["filtered", "tests", ":status"], use: filterCovidTestStatus)
	}

	func filterVaccinationStatus(req: Request) async throws -> [User.Response] {
		guard
			let statusString = req.parameters.get("status"),
			let status = VerificationStatus(rawValue: statusString)
		else {
			throw Abort(.badRequest, reason: "Invalid status.")
		}

		let vaccineRecords = try await VaccinationData
			.query(on: req.db)
			.filter(\.$status == status)
			.all()

		return try await vaccineRecords.concurrentMap { record in
			return try await record.$user.get(on: req.db).getResponse(on: req.db)
		}
	}

	func filterCovidTestStatus(req: Request) async throws -> [User.Response] {
		guard
			let statusString = req.parameters.get("status"),
			let status = VerificationStatus(rawValue: statusString)
		else {
			throw Abort(.badRequest, reason: "Invalid status.")
		}

		let vaccineRecords = try await VaccinationData
			.query(on: req.db)
			.filter(\.$status == status)
			.all()

		return try await vaccineRecords.concurrentMap { record in
			return try await record.$user.get(on: req.db).getResponse(on: req.db)
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

	func me(req: Request) async throws -> User.Response {
		let token = try req.auth.require(AccessToken.self)

		let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db)

		if let user = user {
			return try await user.getResponse(on: req.db)
		} else {
			let sendable = try await req.getUserDetails()

			// Check that the user we get back includes the proper organization.
			guard sendable.organizations.contains(where: { orgRole in
				orgRole.organizationID == req.ticketConfig.organizationID
			}) else {
				throw Abort(.forbidden, reason: "You're not in the organization for \(req.eventConfig.eventName).")
			}

			let user = User(id: sendable.id, name: sendable.name, email: sendable.email)

			try await user.save(on: req.db)

			return try await user.getResponse(on: req.db)
		}
	}
}
