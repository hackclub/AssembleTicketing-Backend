import Vapor

/// Middleware to make sure the user is an admin on Assemble before proceeding.
struct EnsureAdminUserMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let details = try await request.getUserDetails()

		guard details.isAssembleAdmin(on: request.ticketingConfiguration.organizationID) else {
			throw Abort(.forbidden, reason: "Not an admin.")
		}

		return try await next.respond(to: request)
	}
}
