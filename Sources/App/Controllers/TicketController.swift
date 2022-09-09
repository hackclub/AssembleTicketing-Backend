import Fluent
import Vapor
import Mailgun
import PassIssuingKit
import JWT

struct TicketController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let unauthed = routes.grouped("tickets")
		let tickets = routes
			.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
			.grouped("tickets")
		let qr = unauthed.grouped("qr")
		try qr.register(collection: TicketRoutes { user, req in
			try user.generateQRCode(req: req)
		})
		let wallet = unauthed.grouped("wallet")
		try wallet.register(collection: TicketRoutes { user, req in
			try await user.generateWalletPass(req: req)
		})

		let adminAuthed = tickets
			.grouped(EnsureAdminUserMiddleware())
		adminAuthed.group("admin") { ticket in
			ticket.get(["data", ":ticketToken"], use: adminGetCheckInData)
			ticket.get(["checkin", ":ticketToken"], use: adminCheckUserIn)
		}
	}

	struct TicketRoutes: RouteCollection {
		func boot(routes: RoutesBuilder) throws {
			let authenticated = routes
				.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
			authenticated.get(use: fromAuthenticatedUser)
			routes.get(":ticketToken", use: fromTicketToken)
		}

		var generateResponse: (_ user: User, _ req: Request) async throws -> Response

		func fromAuthenticatedUser(req: Request) async throws -> Response {
			let user = try await req.getUser()


			return try await generateResponse(user, req)
		}

		func fromTicketToken(req: Request) async throws -> Response {
			let token = try req.getTicketToken()
			let user = try await User.find(ticketToken: token, on: req.db)

			return try await generateResponse(user, req)
		}
	}

	func getWalletPassUnauthenticated(req: Request) async throws -> Response {
		let token = try req.getTicketToken()
		let user = try await User.find(ticketToken: token, on: req.db)

		return try await user.generateWalletPass(req: req)
	}

	func getWalletPass(req: Request) async throws -> Response {
		let user = try await req.getUser()

		return try await user.generateWalletPass(req: req)
	}

	func adminGetCheckInData(req: Request) async throws -> User.CheckInResponse {
		let token = try req.getTicketToken()
		let user = try await User.find(ticketToken: token, on: req.db)

		return try await user.getCheckInResponse(on: req.db)
	}

	func adminCheckUserIn(req: Request) async throws -> User.CheckInResponse {
		let token = try req.getTicketToken()
		let user = try await User.find(ticketToken: token, on: req.db)

		user.isCheckedIn = true
		try await user.save(on: req.db)

		return try await user.getCheckInResponse(on: req.db)
	}
}

