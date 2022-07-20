import Vapor

extension Request {
	func getUser() async throws -> User {
		let token = try self.auth.require(AccessToken.self)

		guard let user = try await User.find(UUID(uuidString: token.subject.value), on: self.db) else {
			throw Abort(.notFound, reason: "No such user. Try calling /me.")
		}

		return user
	}
}
