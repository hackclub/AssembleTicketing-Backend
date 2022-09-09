import Vapor

extension Request {
	/// Gets
	func getUserDetails() async throws -> User.Detailed {
		guard let authorizationHeader = self.headers.bearerAuthorization else {
			throw Abort(.badRequest, reason: "Missing authorization header.")
		}

		let userRequest = try await self.client.get(
			URI(stringLiteral:
					self.ticketConfig.idAPIURL
					.appendingPathComponent("/users/me").absoluteString
			   ),
			headers: .init(
				[
					("Authorization", "Bearer \(authorizationHeader.token)")
				]
			)
		)

		return try userRequest.content.decode(User.Detailed.self)
	}
}

