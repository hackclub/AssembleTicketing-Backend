import Fluent
import Vapor
import SWCompression
import Crypto
import JWTKit
import ModelsR4
import NIOFoundationCompat

struct VaccinationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
		let authed = routes.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
		// Also allows cookie-based auth
		let cookieAuthed = routes.grouped([AccessToken.cookieAcceptingAuthenticator(), AccessToken.guardMiddleware()])

        let vaccinations = authed.grouped("vaccinations")
        vaccinations.post("verified", use: uploadVerified)
		vaccinations.post(["image", "multipart"], use: uploadImage)

		// Cookie supported routes
		let cookieVaccinations = cookieAuthed.grouped("vaccinations")
		cookieVaccinations.get(use: view)
		cookieVaccinations.get(":hash", use: view)
		cookieVaccinations.post(["image", "base64"], use: uploadImageBase64)

		// Admin routes
		let admin = vaccinations
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")

		admin.group(":userID") { vaccination in
			vaccination.post("status", use: adminSet)
			vaccination.get(use: adminGet)
			vaccination.get(":hash", use: adminGet)
		}
    }

	struct AdminVaccinationUpdate: Content {
		var newStatus: User.VerificationStatus
	}

	/// Allows an admin to set a user's vaccination status manually (e.g, for `humanReviewRequired`).
	/// - Returns: A `VaccinationData.Response` object with the user's new vaccination data.
	func adminSet(req: Request) async throws -> VaccinationData.Response {
		let update = try req.content.decode(AdminVaccinationUpdate.self)

		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}

		guard let vaccinationData = try await user.$vaccinationData.get(on: req.db) else {
			throw Abort(.notFound, reason: "That user hasn't uploaded any vaccination data.")
		}

		let vaccinationRecord = try await vaccinationData.getRecord(on: req.db)

		// Update the status and modification date.
		user.vaccinationStatus = update.newStatus
		vaccinationData.lastModified = Date()

		try await user.save(on: req.db)

		return .init(status: user.vaccinationStatus, record: vaccinationRecord, lastUpdated: Date())
	}

	/// Allows an admin to get more detailed information about a user (including vaccination data).
	func adminGet(req: Request) async throws -> VaccinationData.Response {
		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "No such user")
		}

		guard let vaccinationData = try await user.$vaccinationData.get(on: req.db) else {
			throw Abort(.notFound, reason: "That user hasn't uploaded any vaccination data.")
		}

		let response = try await vaccinationData.getResponse(on: req.db)
		response.isEquivalent(from: req.parameters.get("hash"))

		if let hash = req.parameters.get("hash") {
			let responseHash = response
				.sha256()
				.base64URLEncodedString()

			guard responseHash != hash else {
				throw Abort(.notModified, reason: "Data not modified.")
			}
		}

		return response
	}

	struct HealthCardUpload: Content {
		var qr: String?
		var qrChunks: [String]?
		var jws: String?

		func verify(with req: Request) async throws -> (issuerName: String, payload: SmartHealthCard.Payload) {
			req.logger.log(level: .debug, "verify")
			if let jws = jws {
				req.logger.log(level: .debug, "jws")
				return try await SmartHealthCard.verify(jws: jws, with: req)
			} else if let qr = qr {
				req.logger.log(level: .debug, "qr")
				return try await SmartHealthCard.verify(qr: qr, with: req)
			} else if let qrChunks = qrChunks {
				req.logger.log(level: .debug, "qrChunks")
				return try await SmartHealthCard.verify(qrChunks: qrChunks, with: req)
			} else {
				req.logger.log(level: .debug, "badRequest")
				throw Abort(.badRequest, reason: "Specify chunks or single QR code.")
			}
		}
	}

	/// Upload a verified vaccination record. Note: Will replace the user's previous vaccination record.
	func uploadVerified(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()
		req.logger.log(level: .debug, "Got user")
		let healthCard = try req.content.decode(HealthCardUpload.self)
		req.logger.log(level: .debug, "Decoded health card")

		let (issuerName, payload) = try await healthCard.verify(with: req)

		req.logger.log(level: .debug, "Verified health card")

		guard payload.verifiableCredential.type.contains(.covid19) &&
				payload.verifiableCredential.type.contains(.immunization) &&
				payload.verifiableCredential.type.contains(.healthCard) else {
			throw Abort(.badRequest, reason: "The uploaded card wasn't a COVID immunization record.")
		}

		req.logger.log(level: .debug, "Checked credential type")

		var healthRecord = try payload.verifiableCredential.credentialSubject.fhirBundle.minify()

		req.logger.log(level: .debug, "Minified health card")

		healthRecord.immunizations.sort { lhs, rhs in
			lhs.date < rhs.date
		}

		req.logger.log(level: .debug, "Sorted immunizations")

		guard healthRecord.immunizations.count >= 2 else {
			throw Abort(.badRequest, reason: "The uploaded card only has \(healthRecord.immunizations.count) immunization\(healthRecord.immunizations.count == 1 ? "" : "s") against COVID-19. If you think this is a mistake, check to see if there's another card in the list.")
		}


		req.logger.log(level: .debug, "Checked immunization count")

		// TODO: Make this configurable.
		let assembleDate = Date(timeIntervalSince1970: 1657495648)

		// Check that their second shot is in time for the event.
		guard healthRecord.immunizations[1].date.timeIntervalSince(assembleDate) < -(60 * 60 * 24 * 14) else {
			throw Abort(.conflict, reason: "Your second shot is too recent for Assemble.")
		}


		req.logger.log(level: .debug, "Checked vaccination date.")

		let splitNames = user.name.split(separator: " ")
		guard let firstName = splitNames.first,
			  let lastName = splitNames.last,
			  let patientFirstName = healthRecord.patient.names.first?.split(separator: " ").first,
			  let patientLastName = healthRecord.patient.names.last
		else {
			throw Abort(.badRequest, reason: "We can't parse this name.")
		}


		req.logger.log(level: .debug, "Parsed name")

		let record = Minimized.VerifiedVaccinationRecord(
			issuer: Minimized.Issuer(
				name: issuerName,
				url: payload.issuer
			),
			name: healthRecord.patient.names.joined(separator: " "),
			secondShotDate: healthRecord.immunizations[1].date
		)

		req.logger.log(level: .debug, "Generated record")

		guard
			(
				firstName.lowercased() == patientFirstName.lowercased() ||
				req.ticketingConfiguration.nicknames.value[firstName.lowercased()]?.contains(where: { $0 == patientFirstName.lowercased() }) == true
			) && lastName.lowercased() == patientLastName.lowercased()
		else {
			return try await user.update(status: .verifiedWithDiscrepancy, record: .verified(record: record), on: req.db)
		}

		req.logger.log(level: .debug, "Names matched")

		return try await user.update(status: .verified, record: .verified(record: record), on: req.db)
	}

	func uploadImageBase64(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()
		let input = try req.content.decode(Image.Response.self)

		let image = try Image(from: input)
		try await image.save(on: req.db)

		return try await user.update(status: .humanReviewRequired, record: .image(image: image), on: req.db)
	}

	func uploadImage(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()
		let input = try req.content.decode(File.self)

		let image = try Image(from: input)
		try await image.save(on: req.db)

		return try await user.update(status: .humanReviewRequired, record: .image(image: image), on: req.db)
	}

	func view(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()

		guard let vaccinationData = try await user.$vaccinationData.get(on: req.db) else {
			throw Abort(.notFound, reason: "You haven't uploaded a vaccination yet.")
		}

		let vaccinationRecord = try await vaccinationData.getRecord(on: req.db)

		let response = VaccinationData.Response(status: user.vaccinationStatus, record: vaccinationRecord, lastUpdated: Date())

		if let hash = req.parameters.get("hash") {
			guard response.sha256().base64URLEncodedString() == hash else {
				throw Abort(.notModified, reason: "Data not modified.")
			}
		}

		return response
	}
}

extension VaccinationData.Response {
	func sha256() -> Data {
		var hasher = SHA256()

		// Convert the typeString for the record (e.g, "verified" or "image") to a UTF-8 blob of data
		let recordData = Data(record.typeString.utf8)
		// Convert the status type name to a UTF-8 blob of data
		let statusData = Data(status.rawValue.utf8)
		// Convert the time to second-based UNIX epoch time and the convert that to data
		var intLastModified = Int(self.lastUpdated.timeIntervalSince1970)
		let lastModifiedData = Data(
			bytes: &intLastModified,
			count: MemoryLayout.size(ofValue: intLastModified)
		)

		hasher.update(data: recordData)
		hasher.update(data: statusData)
		hasher.update(data: lastModifiedData)
		let hashed = hasher.finalize()
		let hashedBytes = hashed.compactMap { UInt8($0) }
		let data = Data(hashedBytes)

		return data
	}
}

extension SmartHealthCard.Payload: Content { }


extension Image {
	convenience init(from file: File) throws {
		guard let contentType = file.contentType, contentType.type == "image" else {
			throw Abort(.badRequest, reason: "Invalid content type.")
		}

		self.init(photoData: Data(buffer: file.data), photoType: contentType)
	}

	convenience init(from response: Response) throws {
		guard response.mimeType.type == "image" else {
			throw Abort(.badRequest, reason: "Invalid content type.")
		}

		self.init(photoData: response.data, photoType: response.mimeType)
	}

	convenience init(from upload: Upload) throws {
		guard upload.imageType.type == "image" else {
			throw Abort(.badRequest, reason: "Invalid content type.")
		}

		self.init(photoData: upload.data, photoType: upload.imageType)
	}
}
