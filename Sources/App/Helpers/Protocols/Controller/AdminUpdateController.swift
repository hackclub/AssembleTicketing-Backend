import Vapor
import Fluent
import VaporToOpenAPI

/// A protocol for Controllers that support admin tasks.
protocol AdminUpdateController: Controller {
	/// An associated type to use for the upload of the `adminSet` route.
	associatedtype AdminUpdate: Content, WithAnyExample

	/// Updates the instance of `ObjectType` associated with the user and saves it to the database.
	func adminUpdate(with update: AdminUpdate, for user: User, on db: Database) async throws -> ObjectType
}

extension AdminUpdateController {
	/// A route that takes a given user and returns the appropriate response for the Controller's ObjectType.
	/// Make sure that this is only accessible as admin.
	func adminView(req: Request) async throws -> ObjectType.Response {
		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}

		return try await viewHelper(user, req: req)
	}

	func adminSet(req: Request) async throws -> ObjectType.Response {
		let update = try req.content.decode(AdminUpdate.self)

		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}

		// Update the specific stuff
		let updatedObject = try await adminUpdate(with: update, for: user, on: req.db)

		// Send the user their ticket if the update justifies it
		if try await user.shouldSendTicket(on: req.db) {
			try await user.emailTicket(req: req)
		}

		return try await updatedObject.getResponse(on: req.db)
	}

	/// The admin routes, all grouped as one.
	func adminRoutes(_ routes: RoutesBuilder) throws {
		routes.group(":userID") { admin in
			admin.post(use: adminSet)
				.openAPI(summary: "Set status", description: "Set an object's status with admin credentials", response: ObjectType.Response.self, content: AdminUpdate.self)
			admin.get(use: adminView)
			admin.get(":hash", use: adminView)
		}
	}
}
