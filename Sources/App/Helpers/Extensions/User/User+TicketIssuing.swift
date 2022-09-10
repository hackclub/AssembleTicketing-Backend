import Foundation
import Vapor
import Fluent
import PassIssuingKit
import Mailgun

extension User {
	/// Looks up whether a User should now be sent a ticket to the event.
	func shouldSendTicket(on db: Database) async throws -> Bool {
		// If there isn't anything, count it as false.
		let testVerified = try await self.$testData.get(on: db)?.status.isVerified ?? false
		let vaccinationVerified = try await self.$vaccinationData.get(on: db)?.status.isVerified ?? false
		let waiverSubmitted = self.waiverStatus != nil

		return testVerified && vaccinationVerified && waiverSubmitted
	}

	/// Returns the token for a user's ticket.
	func generateTicketToken(req: Request) throws -> String {
		let payload = try TicketToken(subject: .init(value: self.requireID().uuidString))
		let token = try req.jwt.sign(payload, kid: .tickets)

		return token
	}

	/// Returns an SVG QR code embedded in a Response.
	func generateQRCode(req: Request) throws -> Vapor.Response {
		let token = try self.generateTicketToken(req: req)

		let qr = QRCode(message: Data(token.utf8))
		let qrString = try qr.generateSVGString()

		return .init(
			status: .ok,
			version: .http1_1,
			headers: [
				"Content-Type": "image/svg+xml"
			],
			body: .init(stringLiteral: qrString)
		)
	}

	/// Generates a Wallet pass for the given user.
	func generateWalletPass(req: Request) async throws -> Vapor.Response {
		// The baked-in resources.
		let fileNames = ["icon", "icon@2x", "logo", "logo@2x", "strip", "strip@2x"]
		let fileURLs = try fileNames.map { fileName in
			guard let fileURL = Bundle.module.url(forResource: fileName, withExtension: "png") else {
				print("Failed to add \(fileName)")
				throw Abort(.failedDependency, reason: "Failed to generate Wallet pass.")
			}
			return fileURL
		}

		let token = try self.generateTicketToken(req: req)

		let pass = Pass(
			properties: .init(
				passTypeIdentifier: req.walletConfig.passTypeIdentifier,
				serialNumber: try self.requireID().uuidString,
				teamIdentifier: req.walletConfig.teamID,
				// We don't actually use this, so it doesn't matter as much that it's hardcoded.
				// If you're building support for remote updates into the system, please make the hostname a config parameter.
				webServiceURL: URL(string: "https://api.ticketing.assemble.hackclub.com/tickets/update/")!,
				authenticationToken: token,
				foregroundColor: req.walletConfig.foregroundColor,
				backgroundColor: req.walletConfig.backgroundColor,
				labelColor: req.walletConfig.labelColor,
				barcodes: [
					.init(message: token, format: .qr)
				],
				logoText: req.eventConfig.eventName,
				organizationName: req.eventConfig.organizationName,
				description: "\(req.eventConfig.eventName) Ticket",
				style: .eventTicket(
					body: .init(
						primaryFields: [
							.generic(.init(key: "name", value: self.name))
						], secondaryFields: [
							.generic(.init(key: "loc", value: req.eventConfig.eventLocation, label: "LOCATION")),
							.date(.init(key: "time", value: req.eventConfig.date.iso8601, dateStyle: .medium))
						]
					)
				)
			),
			images: fileURLs
		)

		let passCertURL = req
			.walletConfig
			.passSigningKeyDir
			.appendingPathComponent("walletSigningPass.pem")

		let encodedPass = try pass.issue(using: passCertURL, password: req.walletConfig.passSigningKeyPassword)

		let headers: HTTPHeaders = try [
			"Content-Type": "application/vnd.apple.pkpass",
			"Content-Disposition": "attachment; filename=\"\(self.requireID().uuidString).pkpass\"",
			"Content-Transfer-Encoding": "binary",
			"Accept-Ranges": "bytes"
		]

		return .init(status: .ok, headers: headers, body: .init(data: encodedPass))
	}

	/// Emails a ticket to the given user.
	func emailTicket(req: Request) async throws {
		// Generate the token
		let token = try self.generateTicketToken(req: req)

		// Get it as a QR code
		let qr = QRCode(message: Data(token.utf8))
		let qrData = try qr.generatePNG()
		let qrFile = File(data: ByteBuffer(data: qrData), filename: "qrticket.png")

		// Do the same with the Wallet pass
		guard let walletBadgeURL = Bundle.module.url(forResource: "walletbadge", withExtension: "png") else {
			throw Abort(.internalServerError, reason: "Couldn't find wallet badge.")
		}
		let walletBadgeData = try Data(contentsOf: walletBadgeURL)
		let walletBadge = File(data: .init(data: walletBadgeData), filename: "applewalletbadge.png")

		// Create the message
		let message = MailgunTemplateMessage(
			from: "\(req.eventConfig.eventName)<donotreply@\(req.mailgunConfig.mailgunDomain)>",
			to: self.email,
			subject: "Your Assemble Ticket",
			template: "ticket",
			templateData: ["ticket_qr": token],
			inline: [
				qrFile,
				walletBadge
			]
		)

		let response = try await req.mailgun().send(message).get()

		// and log the response
		req.logger.info("\(response)")
	}
}
