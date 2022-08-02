import Fluent
import Vapor
import QRCodeGenerator
import Mailgun

struct TicketController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let unauthed = routes.grouped("tickets")
		let tickets = routes
			.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
			.grouped("tickets")
		tickets.get("qr", use: getTicketQR)
		unauthed.get(["qr", ":ticketToken"], use: getTicketQRWithToken)
		tickets.get("email", use: emailTicket)

		let adminAuthed = tickets
			.grouped(EnsureAdminUserMiddleware())
		adminAuthed.group("admin") { ticket in
			ticket.get(["data", ":ticketToken"], use: adminGetCheckInData)
			ticket.get(["checkin", ":ticketToken"], use: adminCheckUserIn)
		}
	}

	func getTicketQR(req: Request) async throws -> String {
		let tokenString = try await getTicketToken(req: req)

		print(tokenString)

		// Low error connection because these are going to be on reasonably high-quality mobile device screens
		let qr = try QRCode.encode(text: tokenString, ecl: .low)
		return qr.toSVGString(border: 2)
	}

	func getTicketQRWithToken(req: Request) async throws -> String {
		guard let tokenString = req.parameters.get("ticketToken") else {
			throw Abort(.badRequest, reason: "No token provided.")
		}
		// Validate user input because user input is evil
		_ = try req.jwt.verify(tokenString, as: TicketToken.self)

		let qr = try QRCode.encode(text: tokenString, ecl: .low)
		return qr.toSVGString(border: 2)
	}

	/// Gets the user's ticket token, throwing an error if they're for whatever reason ineligible.
	func getTicketToken(req: Request) async throws -> String {
		let user = try await req.getUser()

		guard user.vaccinationStatus == .verified else {
			throw Abort(.conflict, reason: "Your vaccination wasn't verified.")
		}

		guard user.testStatus == .verified else {
			throw Abort(.conflict, reason: "Your test wasn't verified.")
		}

		guard user.waiverStatus != nil else {
			throw Abort(.conflict, reason: "Your waiver wasn't submitted.")
		}

		let userID = try user.requireID()
		let token = TicketToken(subject: .init(value: userID.uuidString))
		let signedToken = try req.jwt.sign(token, kid: .tickets)
		return signedToken
	}

	func emailTicket(req: Request) async throws -> HTTPStatus {
		let user = try await req.getUser()

		let token = try await getTicketToken(req: req)

		let message = MailgunTemplateMessage(
			from: "Hack Club Assemble<donotreply@mail.assemble.hackclub.com>",
			to: user.email,
			subject: "Your Assemble Ticket",
			template: "ticket",
			templateData: ["ticket_qr": token]
		)

		let mailgunResponse = try await req.mailgun().send(message).get()

		req.logger.log(level: .info, "mailgun response: \(mailgunResponse)")

		return .ok
	}

	/// Just the data the at-the-door person needs to know at a glance.
	struct CheckInResponse: Content {
		var isCheckedIn: Bool
		var isVaccinated: Bool
		var hasTestedNegative: Bool
		var waiverStatus: WaiverStatus?
		var name: String
	}

	func adminGetCheckInData(req: Request) async throws -> CheckInResponse {
		guard let tokenString = req.parameters.get("ticketToken") else {
			throw Abort(.badRequest, reason: "No ticket token provided.")
		}

		let token = try req.jwt.verify(tokenString, as: TicketToken.self)

		guard let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db) else {
			throw Abort(.notFound, reason: "No user with that ID exists.")
		}

		return CheckInResponse(
			isCheckedIn: user.isCheckedIn,
			isVaccinated: user.vaccinationStatus == .verified,
			hasTestedNegative: user.testStatus == .verified,
			waiverStatus: user.waiverStatus,
			name: user.name
		)
	}

	func adminCheckUserIn(req: Request) async throws -> CheckInResponse {
		guard let tokenString = req.parameters.get("ticketToken") else {
			throw Abort(.badRequest, reason: "No ticket token provided.")
		}

		let token = try req.jwt.verify(tokenString, as: TicketToken.self)

		guard let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db) else {
			throw Abort(.notFound, reason: "No user with that ID exists.")
		}

		user.isCheckedIn = true
		try await user.save(on: req.db)

		return CheckInResponse(
			isCheckedIn: user.isCheckedIn,
			isVaccinated: user.vaccinationStatus == .verified,
			hasTestedNegative: user.testStatus == .verified,
			waiverStatus: user.waiverStatus,
			name: user.name
		)
	}
}

enum WaiverStatus: String, Codable {
	/// The mandatory waiver everyone has to sign.
	case mandatory
	/// The freedom waiver.
	case freedom
}
