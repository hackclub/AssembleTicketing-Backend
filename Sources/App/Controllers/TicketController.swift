import Fluent
import Vapor
import QRCodeGenerator
import Mailgun
import PassIssuingKit
import JWT

struct TicketController: RouteCollection {
//	struct TicketTypeHandler<ReturnType: AsyncResponseEncodable>: RouteCollection {
//		var ticketGenerator: (_ token: String, _ user: User, _ request: Request) async throws -> ReturnType
//
//		func boot(routes: RoutesBuilder) throws {
//			let authenticated = routes
//				.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
//			authenticated.get(use: fromAuthenticatedUser)
//			routes.get(":ticketToken", use: fromExistingToken)
//		}
//
//		/// Validates a provided ticket token, returning the token if valid.
//		static func validateTicketToken(req: Request) async throws -> (tokenString: String, token: TicketToken, user: User) {
//			guard let tokenString = req.parameters.get("ticketToken") else {
//				throw Abort(.badRequest, reason: "No token provided.")
//			}
//			// Validate user input because user input is evil
//			let token = try req.jwt.verify(tokenString, as: TicketToken.self)
//
//			guard let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db) else {
//				throw Abort(.notFound, reason: "No user exists for this token.")
//			}
//
//			return (tokenString, token, user)
//		}
//
//		/// Gets the signed in user's ticket token, throwing an error if they're for whatever reason ineligible.
//		static func getTicketToken(req: Request) async throws -> (tokenString: String, token: TicketToken, user: User) {
//			let user = try await req.getUser()
//
//			return try await getTicketToken(user: user, jwt: req.jwt)
//		}
//
//		/// Get a specific user's ticket token. Only call this route from admin routes.
//		static func getTicketToken(user: User, jwt: Request.JWT) async throws -> (tokenString: String, token: TicketToken, user: User) {
//
//			guard
//				let vaccinationStatus = user.$vaccinationData.get(on: req.db),
//				vaccinationStatus == .verified else
//			{
//				throw Abort(.conflict, reason: "Your vaccination wasn't verified.")
//			}
//
//			guard user.testStatus == .verified else {
//				throw Abort(.conflict, reason: "Your test wasn't verified.")
//			}
//
//			guard user.waiverStatus != nil else {
//				throw Abort(.conflict, reason: "Your waiver wasn't submitted.")
//			}
//
//			let userID = try user.requireID()
//			let token = TicketToken(subject: .init(value: userID.uuidString))
//			let signedToken = try jwt.sign(token, kid: .tickets)
//			return (signedToken, token, user)
//		}
//
//		func fromExistingToken(req: Request) async throws -> ReturnType {
//			let (tokenString, token, user) = try await Self.validateTicketToken(req: req)
//
//			return try await ticketGenerator(tokenString, user, req)
//		}
//
//		func fromAuthenticatedUser(req: Request) async throws -> ReturnType {
//			let (tokenString, token, user) = try await Self.getTicketToken(req: req)
//
//			return try await ticketGenerator(tokenString, user, req)
//		}
//	}
//
	func boot(routes: RoutesBuilder) throws {
//		let unauthed = routes.grouped("tickets")
//		let tickets = routes
//			.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
//			.grouped("tickets")
//		let qr = unauthed.grouped("qr")
//		try qr.register(collection: TicketTypeHandler(ticketGenerator: generateQR))
//		let wallet = unauthed.grouped("wallet")
//		try wallet.register(collection: TicketTypeHandler(ticketGenerator: generateWalletPass))
//
//		tickets.get("email", use: emailTicket)
//
//		let adminAuthed = tickets
//			.grouped(EnsureAdminUserMiddleware())
//		adminAuthed.group("admin") { ticket in
//			ticket.get(["data", ":ticketToken"], use: adminGetCheckInData)
//			ticket.get(["checkin", ":ticketToken"], use: adminCheckUserIn)
//			ticket.get(["email", ":userID"], use: adminEmailUserTickets)
//		}
	}
//
//	static func generateQRString(token: String) throws -> String {
//		// Low error connection because these are going to be on reasonably high-quality mobile device screens
//		let qr = try QRCode.encode(text: token, ecl: .low)
//		let svgString = qr.toSVGString(border: 2)
//
//		return svgString
//	}
//
//	func generateQR(token: String, user: User, request: Request) async throws -> Response {
//		let svgString = try Self.generateQRString(token: token)
//
//		let headers: HTTPHeaders = [
//			"Content-Type": "image/svg+xml"
//		]
//
//		return .init(status: .ok, headers: headers, body: .init(string: svgString))
//	}
//
	func generateWalletPass(token: String, user: User, request: Request) async throws -> Response {
		// The baked-in resources.
		let fileNames = ["icon", "icon@2x", "logo", "logo@2x", "strip", "strip@2x"]
		let fileURLs = try fileNames.map { fileName in
			guard let fileURL = Bundle.module.url(forResource: fileName, withExtension: "png") else {
				print("Failed to add \(fileName)")
				throw Abort(.failedDependency, reason: "Failed to generate Wallet pass.")
			}
			return fileURL
		}

		let pass = Pass(
			properties: .init(
				passTypeIdentifier: request.walletConfig.passTypeIdentifier,
				serialNumber: try user.requireID().uuidString,
				teamIdentifier: request.walletConfig.teamID,
				// We don't actually use this, so it doesn't matter as much that it's hardcoded.
				// If you're building support for remote updates into the system, please make the hostname a config parameter.
				webServiceURL: URL(string: "https://api.ticketing.assemble.hackclub.com/tickets/update/")!,
				authenticationToken: token,
				logoText: request.eventConfig.eventName,
				organizationName: request.eventConfig.organizationName,
				description: "\(request.eventConfig.eventName) Ticket",
				style: .eventTicket(
					body: .init(
						primaryFields: [
							.generic(.init(key: "name", value: user.name))
						], secondaryFields: [
							.generic(.init(key: "loc", value: request.eventConfig.eventLocation, label: "LOCATION")),
							.date(.init(key: "time", value: request.eventConfig.date.ISO8601Format(), dateStyle: .medium))
						]
					)
				)),
			images: fileURLs
		)

		let passCertURL = request
			.walletConfig
			.passSigningKeyDir
			.appendingPathComponent("walletSigningPass.pem")

		let encodedPass = try pass.issue(using: passCertURL, password: request.walletConfig.passSigningKeyPassword)

		let headers: HTTPHeaders = try [
			"Content-Type": "application/vnd.apple.pkpass",
			"Content-Disposition": "attachment; filename=\"\(user.requireID().uuidString).pkpass\"",
			"Content-Transfer-Encoding": "binary",
			"Accept-Ranges": "bytes"
		]

		let response = Response(status: .ok, headers: headers, body: .init(data: encodedPass))
		return response
	}
//
//
//	func emailTicket(req: Request) async throws -> HTTPStatus {
//		let user = try await req.getUser()
//
//		return try await Self.emailTicket(user: user, mailgun: req.mailgun(), jwt: req.jwt, client: req.client)
//	}
//
//
//	// TODO: Clean this entirely up.
//	static func emailTicket(user: User, mailgun: MailgunProvider, jwt: Request.JWT, client: Client) async throws -> HTTPStatus {
//		let (tokenString, _, _) = try await TicketTypeHandler<HTTPStatus>.getTicketToken(user: user, jwt: jwt)
//
//		let qrString = try generateQRString(token: tokenString)
//
//		guard let walletBadgeURL = Bundle.module.url(forResource: "walletbadge", withExtension: "png") else {
//			throw Abort(.internalServerError, reason: "Couldn't find wallet badge.")
//		}
//
//		let pngResponse = try await client.post("https://svg2png-production.up.railway.app/png", headers: ["Content-Type": "text/plain; charset=utf-8"]) { request in
//			try request.content.encode(qrString)
//		}
//
//		guard let pngData = pngResponse.body else {
//			throw Abort(.internalServerError, reason: "Couldn't convert QR to PNG.")
//		}
//		let qrPNG = File(data: pngData, filename: "qrticket.png")
//
//		let walletBadgeData = try Data(contentsOf: walletBadgeURL)
//		let walletBadge = File(data: .init(data: walletBadgeData), filename: "applewalletbadge.png")
//
//		let message = MailgunTemplateMessage(
//			from: "Hack Club Assemble<donotreply@mail.assemble.hackclub.com>",
//			to: user.email,
//			subject: "Your Assemble Ticket",
//			template: "ticket",
//			templateData: ["ticket_qr": tokenString],
//			inline: [
//				qrPNG,
//				walletBadge
//			]
//		)
//
//		let response = try await mailgun.send(message).get()
//
//		print(response)
//
//		return .ok
//	}
//
//	/// Just the data the at-the-door person needs to know at a glance.
//	struct CheckInResponse: Content {
//		var isCheckedIn: Bool
//		var isVaccinated: Bool
//		var hasTestedNegative: Bool
//		var waiverStatus: User.WaiverStatus?
//		var name: String
//	}
//
//	func adminGetCheckInData(req: Request) async throws -> CheckInResponse {
//		guard let tokenString = req.parameters.get("ticketToken") else {
//			throw Abort(.badRequest, reason: "No ticket token provided.")
//		}
//
//		let token = try req.jwt.verify(tokenString, as: TicketToken.self)
//
//		guard let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db) else {
//			throw Abort(.notFound, reason: "No user with that ID exists.")
//		}
//
//		let vaccinationStatus = try await user.$vaccinationData.get(on: req.db)?.status
//		let covidTestStatus = try await user.$testData.get(on: req.db)?.status
//
//		return CheckInResponse(
//			isCheckedIn: user.isCheckedIn,
//			isVaccinated: vaccinationStatus == .verified,
//			hasTestedNegative: covidTestStatus == .verified,
//			waiverStatus: user.waiverStatus,
//			name: user.name
//		)
//	}
//
//	func adminCheckUserIn(req: Request) async throws -> CheckInResponse {
//		guard let tokenString = req.parameters.get("ticketToken") else {
//			throw Abort(.badRequest, reason: "No ticket token provided.")
//		}
//
//		let token = try req.jwt.verify(tokenString, as: TicketToken.self)
//
//		guard let user = try await User.find(UUID(uuidString: token.subject.value), on: req.db) else {
//			throw Abort(.notFound, reason: "No user with that ID exists.")
//		}
//
//		user.isCheckedIn = true
//		try await user.save(on: req.db)
//
//		return CheckInResponse(
//			isCheckedIn: user.isCheckedIn,
//			isVaccinated: user.vaccinationStatus == .verified,
//			hasTestedNegative: user.testStatus == .verified,
//			waiverStatus: user.waiverStatus,
//			name: user.name
//		)
//	}
//
//	func adminEmailUserTickets(req: Request) async throws -> HTTPStatus {
//		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
//			throw Abort(.notFound, reason: "There's no user with that ID.")
//		}
//
//		return try await Self.emailTicket(user: user, mailgun: req.mailgun(), jwt: req.jwt, client: req.client)
//	}
}
