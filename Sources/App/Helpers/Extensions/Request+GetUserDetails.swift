import Vapor

extension Request {
	func getUserDetails() async throws -> SendableUser {
		guard let authorizationHeader = self.headers.bearerAuthorization else {
			throw Abort(.badRequest, reason: "Missing authorization header.")
		}

		let userRequest = try await self.client.get("https://api.allotrope.id/users/me", headers: .init([
			("Authorization", "Bearer \(authorizationHeader.token)")
		]))

		return try userRequest.content.decode(SendableUser.self)
	}
}

