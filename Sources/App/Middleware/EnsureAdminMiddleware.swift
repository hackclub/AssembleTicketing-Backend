import Vapor

/// Middleware to make sure the user is an admin on Assemble before proceeding.
struct EnsureAdminUserMiddleware: AsyncMiddleware {
	func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
		let details = try await request.getUserDetails()

		guard details.isAssembleAdmin(on: request.ticketConfig.organizationID) else {
			throw Abort(.forbidden, reason: "You're not an admin.")
		}

		return try await next.respond(to: request)
	}
}
