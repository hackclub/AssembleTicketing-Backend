import Vapor
import Fluent

extension Request {
	/// Returns a provided User object (if available), defaulting to the requesting user if not.
	/// - Parameters:
	///   - user: An optional provided user that will be returned if provided.
	func unwrapUser(user: User?) async throws -> User {
		guard let user = user else {
			return try await self.getUser()
		}
		return user
	}
}
