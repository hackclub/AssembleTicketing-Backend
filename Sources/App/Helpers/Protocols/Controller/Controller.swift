import Vapor
import Fluent

/// A protocol describing a Controller that manages a specific associated object type.
protocol Controller: RouteCollection {
	associatedtype ObjectType: ResponseEncodable where ObjectType.Response: ResponseHashable

	/// Finds and gets an existing model on the database, looking up based on the appropriate user.
	func getExistingModel(for user: User, on db: Database) async throws -> ObjectType?

}

extension Controller {
	/// A route that returns the `ObjectType` instance associated with the requesting user.
	func view(req: Request) async throws -> ObjectType.Response {
		try await viewHelper(req: req)
	}

	/// A route helper that (optionally) accepts a provided user and returns the appropriate response for the Controller's `ObjectType`.
	func viewHelper(_ providedUser: User? = nil, req: Request) async throws -> ObjectType.Response {
		let user = try await req.unwrapUser(user: providedUser)

		guard let model = try await getExistingModel(for: user, on: req.db) else {
			throw Abort(.notFound, reason: "No \(ObjectType.self) for this user.")
		}

		let response = try await model.getResponse(on: req.db)

		if let hash = req.parameters.get("hash") {
			guard response.sha256().base64URLEncodedString() == hash else {
				throw Abort(.notModified, reason: "Data not modified.")
			}
		}

		return response
	}

	/// The general controller routes, all grouped as one.
	func generalRoutes(_ routes: RoutesBuilder) throws {
		routes.get(use: view)
	}
}

extension Controller where Self: AdminUpdateController, Self: ImageUploadController {
	/// A helper method for all the various routes of the various types of controllers.
	func allRoutes(routes: RoutesBuilder) throws {
		let authed = routes.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
		// Also allows cookie-based auth
		let cookieAuthed = routes.grouped([AccessToken.cookieAcceptingAuthenticator(), AccessToken.guardMiddleware()])

		try generalRoutes(authed)

		let image = cookieAuthed
			.grouped("image")

		try imageRoutes(image)

		// Admin routes
		let admin = routes
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")

		try adminRoutes(admin)
	}
}
