import Fluent
import Vapor
import SWCompression
import Crypto
import JWTKit
import ModelsR4
import NIOFoundationCompat


struct VaccinationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let vaccinations = routes.grouped("vaccinations")

        vaccinations.post("verified", use: uploadVerified)
		let image = vaccinations.grouped("image")
		image.post("base64", use: uploadImageBase64)
		image.post("multipart", use: uploadImage)
		vaccinations.get(use: view)
		let admin = vaccinations
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")

		admin.group(":userID") { vaccination in
			vaccination.post("status", use: adminSet)
			vaccination.get(use: adminGet)
		}
    }

	struct AdminVaccinationUpdate: Content {
		var newStatus: User.VaccinationVerificationStatus
	}

	/// Allows an admin to set a user's vaccination status manually (e.g, for `humanReviewRequired`).
	/// - Returns: A `User` object with the vaccination data prefilled.
	func adminSet(req: Request) async throws -> User.Response {
		let update = try req.content.decode(AdminVaccinationUpdate.self)

		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "No such user")
		}

		user.vaccinationStatus = update.newStatus

		try await user.save(on: req.db)

		try await user.$vaccinationData.load(on: req.db)

		return try user.response()
	}

	/// Allows an admin to get more detailed information about a user (including vaccination data).
	func adminGet(req: Request) async throws -> User.Response {
		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "No such user")
		}

		try await user.$vaccinationData.load(on: req.db)

		return try .init(user)
	}

	struct HealthCardData: Content {
		var qr: String?
		var qrChunks: [String]?
		var jws: String?

		func verify() async throws -> (issuerName: String, payload: SmartHealthCard.Payload) {
			if let jws = jws {
				return try await SmartHealthCard.verify(jws: jws)
			} else if let qr = qr {
				return try await SmartHealthCard.verify(qr: qr)
			} else if let qrChunks = qrChunks {
				return try await SmartHealthCard.verify(qrChunks: qrChunks)
			} else {
				throw Abort(.badRequest, reason: "Specify chunks or single QR code.")
			}
		}
	}

	/// Upload a verified vaccination record. Note: Will replace the user's previous vaccination record.
	func uploadVerified(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()
		req.logger.log(level: .debug, "Got user")
		let healthCard = try req.content.decode(HealthCardData.self)
		req.logger.log(level: .debug, "Decoded health card")
		let (issuerName, payload) = try await healthCard.verify()
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
				nicknames[firstName.lowercased()]?.contains(where: { $0 == patientFirstName.lowercased() }) == true
			) && lastName.lowercased() == patientLastName.lowercased()
		else {
			return try await user.update(status: .verifiedWithDiscrepancy, record: .verified(record: record), on: req.db)
		}

		req.logger.log(level: .debug, "Names matched")

		return try await user.update(status: .verified, record: .verified(record: record), on: req.db)
	}

	struct Base64Image: Content {
		var mimeType: HTTPMediaType
		var data: Data
	}

	func uploadImageBase64(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()
		let input = try req.content.decode(Base64Image.self)

		guard input.mimeType.type == "image" else {
			throw Abort(.badRequest, reason: "Must be an image.")
		}

		return try await user.update(status: .humanReviewRequired, record: .image(data: input.data, filetype: input.mimeType), on: req.db)
	}

	func uploadImage(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()
		let input = try req.content.decode(File.self)

		guard let contentType = input.contentType, contentType.type == "image" else {
			throw Abort(.badRequest, reason: "Must be an image.")
		}

		let data = Data(buffer: input.data)

		return try await user.update(status: .humanReviewRequired, record: .image(data: data, filetype: contentType), on: req.db)
	}

	func view(req: Request) async throws -> VaccinationData.Response {
		let user = try await req.getUser()

		guard let vaccinationData = try await user.$vaccinationData.get(on: req.db) else {
			throw Abort(.notFound, reason: "No vaccination for this user")
		}

		guard let record = vaccinationData.record else {
			throw Abort(.notFound, reason: "No data in vaccination record.")
		}

		return .init(status: user.vaccinationStatus, record: record, lastUpdated: vaccinationData.lastModified)
	}
}

extension SmartHealthCard.Payload: Content { }

extension User {
	/// A version of User meant to be sent over the wire with a VaccinationResponse.
	struct Response: Content {
		var id: UUID
		var name: String
		var email: String
		var vaccinationData: VaccinationData.Response?

		/// Creates a Response from a User. Will include vaccination data if eager-loaded.
		init(_ user: User) throws {
			self.id = try user.requireID()
			self.name = user.name
			self.email = user.email

			// Weird double-question-mark to handle loading (only send the value if pre-loaded)
			if let wrappedVaccinationData = user.$vaccinationData.value, let vaccinationData = wrappedVaccinationData, let record = vaccinationData.record {
				self.vaccinationData = .init(status: user.vaccinationStatus, record: record, lastUpdated: vaccinationData.lastModified)
			}
		}
	}

	/// Get a response object for the current user.
	func response() throws -> Response {
		return try .init(self)
	}
}

extension User {
	/// Updates a user and returns a VaccinationResponse in one fell swoop
	func update(status: VaccinationVerificationStatus, record: VaccinationData.Response.RecordType, on db: Database) async throws -> VaccinationData.Response {
		self.vaccinationStatus = status

		try await self.save(on: db)
		// Make sure we don't have two vaccination records for a user
		if let oldVaccinationData = try await self.$vaccinationData.get(on: db) {
			try await oldVaccinationData.delete(on: db)
		}

		let vaccinationData = VaccinationData(record)

		// Add the new data
		try await self.$vaccinationData.create(vaccinationData, on: db)

		return .init(status: status, record: record, lastUpdated: vaccinationData.lastModified)
	}
}

extension VaccinationData {
	convenience init(_ record: VaccinationData.Response.RecordType) {
		switch record {
			case .image(let imageData, let fileType):
				self.init(photoData: imageData, photoType: fileType)
			case .verified(let verifiedRecord):
				self.init(verifiedVaccination: verifiedRecord)
		}
	}

	var record: VaccinationData.Response.RecordType? {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageVaccination = self.photoData, let imageType = self.photoType {
			return .image(data: imageVaccination, filetype: imageType)
		}
		return nil
	}

	func getResponse(on db: Database) async throws -> VaccinationData.Response {
		guard let record = self.record else {
			throw Abort(.notFound, reason: "No data in vaccination record.")
		}
		return try await .init(status: self.$user.get(on: db).vaccinationStatus, record: record, lastUpdated: lastModified)
	}
}


extension VaccinationData {
	/// The response to a vaccination verification request.
	struct Response: Content {
		/// The status of the verification after upload.
		var status: User.VaccinationVerificationStatus
		/// The vaccination record that was saved.
		var record: RecordType
		/// The time the record was last updated.
		var lastUpdated: Date

		/// The types of vaccination record.
		enum RecordType: Codable {
			/// A verified vaccination record.
			case verified(record: Minimized.VerifiedVaccinationRecord)
			/// An image vaccination record.
			case image(data: Data, filetype: HTTPMediaType)
		}
	}
}
