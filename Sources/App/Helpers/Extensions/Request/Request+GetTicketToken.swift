import Vapor

extension Request {
	/// Get a ticket token from the request (if available).
	func getTicketToken() throws -> TicketToken {
		guard let tokenString = self.parameters.get("ticketToken") else {
			throw Abort(.badRequest, reason: "No ticket token provided.")
		}

		let token = try self.jwt.verify(tokenString, as: TicketToken.self)
		return token
	}
}

