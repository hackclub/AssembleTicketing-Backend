import Fluent
import Vapor
import QRCodeGenerator
import Mailgun
import PassEncoder
import JWT

struct TicketController: RouteCollection {
	struct TicketTypeHandler<ReturnType: AsyncResponseEncodable>: RouteCollection {
		var ticketGenerator: (_ token: String, _ user: User, _ request: Request) async throws -> ReturnType

		func boot(routes: RoutesBuilder) throws {
			let authenticated = routes
				.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
			authenticated.get(use: fromAuthenticatedUser)
			routes.get(":ticketToken", use: fromExistingToken)
		}

		/// Validates a provided ticket token, returning the token if valid.
		static func validateTicketToken(req: Request) async throws -> (tokenString: String, token: TicketToken, user: User) {
			guard let tokenString = req.parameters.get("ticketToken") else {
				throw Abort(.badRequest, reason: "No token provided.")
			}
			// Validate user input because user input is evil
			let token = try req.jwt.verify(tokenString, as: TicketToken.self)

			guard let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db) else {
				throw Abort(.notFound, reason: "No user exists for this token.")
			}

			return (tokenString, token, user)
		}

		/// Gets the signed in user's ticket token, throwing an error if they're for whatever reason ineligible.
		static func getTicketToken(req: Request) async throws -> (tokenString: String, token: TicketToken, user: User) {
			let user = try await req.getUser()

			return try await getTicketToken(user: user, jwt: req.jwt)
		}

		/// Get a specific user's ticket token. Only call this route from admin routes.
		static func getTicketToken(user: User, jwt: Request.JWT) async throws -> (tokenString: String, token: TicketToken, user: User) {
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
			let signedToken = try jwt.sign(token, kid: .tickets)
			return (signedToken, token, user)
		}

		func fromExistingToken(req: Request) async throws -> ReturnType {
			let (tokenString, token, user) = try await Self.validateTicketToken(req: req)

			return try await ticketGenerator(tokenString, user, req)
		}

		func fromAuthenticatedUser(req: Request) async throws -> ReturnType {
			let (tokenString, token, user) = try await Self.getTicketToken(req: req)

			return try await ticketGenerator(tokenString, user, req)
		}
	}

	func boot(routes: RoutesBuilder) throws {
		let unauthed = routes.grouped("tickets")
		let tickets = routes
			.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
			.grouped("tickets")
		let qr = unauthed.grouped("qr")
		try qr.register(collection: TicketTypeHandler(ticketGenerator: generateQR))
		let wallet = unauthed.grouped("wallet")
		try wallet.register(collection: TicketTypeHandler(ticketGenerator: generateWalletPass))

		tickets.get("email", use: emailTicket)

		let adminAuthed = tickets
			.grouped(EnsureAdminUserMiddleware())
		adminAuthed.group("admin") { ticket in
			ticket.get(["data", ":ticketToken"], use: adminGetCheckInData)
			ticket.get(["checkin", ":ticketToken"], use: adminCheckUserIn)
			ticket.get(["email", ":userID"], use: adminEmailUserTickets)
		}
	}

	func generateQR(token: String, user: User, request: Request) async throws -> Response {
		// Low error connection because these are going to be on reasonably high-quality mobile device screens
		let qr = try QRCode.encode(text: token, ecl: .low)
		let svgString = qr.toSVGString(border: 2)
		let headers: HTTPHeaders = [
			"Content-Type": "image/svg+xml"
		]

		return .init(status: .ok, headers: headers, body: .init(string: svgString))
	}

	func generateWalletPass(token: String, user: User, request: Request) async throws -> Response {
		let pass = try AppleWalletEventTicket(
			passTypeIdentifier: "pass.com.hackclub.event.summer.2022",
			serialNumber: user.requireID().uuidString,
			teamIdentifier: "P6PV2R9443",
			webServiceURL: URL(string: "https://api.ticketing.assemble.hackclub.com/tickets/update/")!,
			authenticationToken: token,
			// TODO: Make event date configurable
			relevantDate: .init(timeIntervalSince1970: 1659747600),
			foregroundColor: .init(hex: "ffffff"),
			backgroundColor: .init(hex: "C0362C"),
			labelColor: .init(hex: "ffffff"),
			// NOTE: This doesn't work due to (I think) some weird float conversion bug. 
//			locations: [
//				.init(
//					longitude:
//						round(37.7865 * 10_000) / 10_000,
//					latitude:
//						round(-122.4053 * 10_000) / 10_000
//				)
//			],
			barcodes: [
				.init(message: token, format: .qr)
			],
			logoText: "Assemble",
			organizationName: "The Hack Foundation",
			description: "Hack Club Assemble Ticket",
			eventTicket: .init(
				primaryFields: [
					.init(key: "name", value: user.name)
				], secondaryFields: [
					.init(key: "loc", value: "Figma HQ", label: "LOCATION"),
					.init(key: "time", value: "2022-08-05T18:00:00-07:00", label: "DATE", dateStyle: .medium, isRelative: true)
				]
			)
		)

		// Encode the pass to give to PassEncoder
		let encoder = JSONEncoder()
		encoder.dateEncodingStrategy = .iso8601

		let passData = try encoder.encode(pass)

		guard let passEncoder = PassEncoder.init(passData: passData) else {
			throw Abort(.internalServerError, reason: "Couldn't generate pass.")
		}

		let fileNames = ["icon", "icon@2x", "logo", "logo@2x", "strip", "strip@2x"]

		for fileName in fileNames {
			guard let fileURL = Bundle.module.url(forResource: fileName, withExtension: "png") else {
				print("Failed to add \(fileName)")
				continue
			}

			guard passEncoder.addFile(from: fileURL) else {
				print("Failed to add file at url \(fileURL)")
				continue
			}
		}

		let passCertURL = request
			.ticketingConfiguration
			.ticketSigningKeyDir
			.appendingPathComponent("walletSigningPass.pem")

		guard let encodedPass = passEncoder.encode(signingInfo: (certificate: passCertURL, password: request.ticketingConfiguration.passSigningKeyPassword)) else {
			throw Abort(.internalServerError, reason: "Couldn't generate pass.")
		}

		let headers: HTTPHeaders = try [
			"Content-Type": "application/vnd.apple.pkpass",
			"Content-Disposition": "attachment; filename=\"\(user.requireID().uuidString).pkpass\"",
			"Content-Transfer-Encoding": "binary",
			"Accept-Ranges": "bytes"
		]

		let response = Response(status: .ok, headers: headers, body: .init(data: encodedPass))
		return response
	}


	func emailTicket(req: Request) async throws -> HTTPStatus {
		let user = try await req.getUser()

		return try await emailTicket(user: user, mailgun: req.mailgun(), jwt: req.jwt)
	}

	func emailTicket(user: User, mailgun: MailgunProvider, jwt: Request.JWT) async throws -> HTTPStatus {
		let (tokenString, _, _) = try await TicketTypeHandler<HTTPStatus>.getTicketToken(user: user, jwt: jwt)

		let message = MailgunTemplateMessage(
			from: "Hack Club Assemble<donotreply@mail.assemble.hackclub.com>",
			to: user.email,
			subject: "Your Assemble Ticket",
			template: "ticket",
			templateData: ["ticket_qr": tokenString]
		)

		let _ = try await mailgun.send(message).get()

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

	func adminEmailUserTickets(req: Request) async throws -> HTTPStatus {
		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}

		return try await emailTicket(user: user, mailgun: req.mailgun(), jwt: req.jwt)
	}
}

// TODO: Move this to its own file.
enum WaiverStatus: String, Codable {
	/// The mandatory waiver everyone has to sign.
	case mandatory
	/// The freedom waiver.
	case freedom
}

extension AppleWalletEventTicket: Content {}
