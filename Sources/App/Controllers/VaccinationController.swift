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
		image.post(use: uploadImage)
		vaccinations.get(use: view)
		let admin = vaccinations
			.grouped(EnsureAdminUserMiddleware())
			.grouped("admin")

		admin.group(":userID") { vaccination in
			vaccination.post("status", use: adminSet)
		}
    }

	struct AdminVaccinationUpdate: Content {
		var newStatus: User.VaccinationVerificationStatus
	}

	/// Allows an admin to set a user's vaccination status manually (e.g, for `humanReviewRequired`).
	/// - Returns: A `User` object with the vaccination data prefilled.
	func adminSet(req: Request) async throws -> User {
		let update = try req.content.decode(AdminVaccinationUpdate.self)

		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "No such user")
		}

		user.vaccinationStatus = update.newStatus

		try await user.save(on: req.db)

		try await user.$vaccinationData.load(on: req.db)

		return user
	}

	struct HealthCardData: Content {
		var qr: String?
		var qrChunks: [String]?

		func verify() async throws -> (issuerName: String, payload: SmartHealthCard.Payload) {
			if let qr = qr {
				return try await SmartHealthCard.verify(qr: qr)
			} else if let qrChunks = qrChunks {
				return try await SmartHealthCard.verify(qrChunks: qrChunks)
			} else {
				throw Abort(.badRequest, reason: "Specify chunks or single QR code.")
			}
		}
	}

	/// The response to a vaccination verification request.
	struct VaccinationResponse: Content {
		/// The status of the verification after upload.
		var status: User.VaccinationVerificationStatus
		/// The vaccination record that was saved.
		var record: RecordType

		/// The types of vaccination record.
		enum RecordType: Codable {
			/// A verified vaccination record.
			case verified(record: Minimized.VerifiedVaccinationRecord)
			/// An image vaccination record.
			case image(data: Data, filetype: HTTPMediaType)
		}
	}

	/// Upload a verified vaccination record. Note: Will replace the user's previous vaccination record.
	func uploadVerified(req: Request) async throws -> VaccinationResponse {
		let user = try await req.getUser()
		let healthCard = try req.content.decode(HealthCardData.self)
		let (issuerName, payload) = try await healthCard.verify()

		guard payload.verifiableCredential.type.contains(.covid19) &&
				payload.verifiableCredential.type.contains(.immunization) &&
				payload.verifiableCredential.type.contains(.healthCard) else {
			throw Abort(.badRequest, reason: "Wrong type of health card.")
		}

		var healthRecord = try payload.verifiableCredential.credentialSubject.fhirBundle.minify()

		healthRecord.immunizations.sort { lhs, rhs in
			lhs.date < rhs.date
		}

		guard healthRecord.immunizations.count >= 2 else {
			throw Abort(.badRequest, reason: "Not enough immunizations against COVID-19.")
		}

		// TODO: Make this configurable.
		let assembleDate = Date(timeIntervalSince1970: 1657495648)

		// Check that their second shot is in time for the event.
		guard healthRecord.immunizations[1].date.timeIntervalSince(assembleDate) < -(60 * 60 * 24 * 14) else {
			throw Abort(.conflict, reason: "Vaccination is too recent for Assemble.")
		}

		let splitNames = user.name.split(separator: " ")
		guard let firstName = splitNames.first,
			  let lastName = splitNames.last,
			  let patientFirstName = healthRecord.patient.names.first?.split(separator: " ").first,
			  let patientLastName = healthRecord.patient.names.last
		else {
			throw Abort(.badRequest, reason: "We can't parse this name.")
		}

		let record = Minimized.VerifiedVaccinationRecord(
			issuer: Minimized.Issuer(
				name: issuerName,
				url: payload.issuer
			),
			name: healthRecord.patient.names.joined(separator: " "),
			secondShotDate: healthRecord.immunizations[1].date
		)

		guard
			(
				firstName.lowercased() == patientFirstName.lowercased() ||
				nicknames[firstName.lowercased()]?.contains(where: { $0 == patientFirstName.lowercased() }) == true
			) && lastName.lowercased() == patientLastName.lowercased()
		else {
			return try await user.update(status: .verifiedWithDiscrepancy, record: .verified(record: record), on: req.db)
		}

		return try await user.update(status: .verified, record: .verified(record: record), on: req.db)
	}

	func uploadImage(req: Request) async throws -> VaccinationResponse {
		let user = try await req.getUser()
		let input = try req.content.decode(File.self)

		guard let contentType = input.contentType, contentType.type == "image" else {
			throw Abort(.badRequest, reason: "Must be an image.")
		}

		let data = Data(buffer: input.data)

		return try await user.update(status: .humanReviewRequired, record: .image(data: data, filetype: contentType), on: req.db)
	}

	func view(req: Request) async throws -> VaccinationResponse {
		let user = try await req.getUser()

		guard let vaccinationData = try await user.$vaccinationData.get(on: req.db) else {
			throw Abort(.notFound, reason: "No vaccination for this user")
		}

		guard let record = vaccinationData.record else {
			throw Abort(.notFound, reason: "No data in vaccination record.")
		}

		return .init(status: user.vaccinationStatus, record: record)
	}
}

extension SmartHealthCard.Payload: Content { }

extension User {
	/// Updates a user and returns a VaccinationResponse in one fell swoop
	func update(status: VaccinationVerificationStatus, record: VaccinationController.VaccinationResponse.RecordType, on db: Database) async throws -> VaccinationController.VaccinationResponse {
		self.vaccinationStatus = status

		try await self.save(on: db)
		// Make sure we don't have two vaccination records for a user
		if let oldVaccinationData = try await self.$vaccinationData.get(on: db) {
			try await oldVaccinationData.delete(on: db)
		}

		// Add the new data
		try await self.$vaccinationData.create(VaccinationData(record), on: db)

		return .init(status: status, record: record)
	}
}

extension VaccinationData {
	convenience init(_ record: VaccinationController.VaccinationResponse.RecordType) {
		switch record {
			case .image(let imageData, let fileType):
				self.init(photoData: imageData, photoType: fileType)
			case .verified(let verifiedRecord):
				self.init(verifiedVaccination: verifiedRecord)
		}
	}

	var record: VaccinationController.VaccinationResponse.RecordType? {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageVaccination = self.photoData, let imageType = self.photoType {
			return .image(data: imageVaccination, filetype: imageType)
		}
		return nil
	}

	func getResponse(on db: Database) async throws -> VaccinationController.VaccinationResponse {
		guard let record = self.record else {
			throw Abort(.notFound, reason: "No data in vaccination record.")
		}
		return try await .init(status: self.$user.get(on: db).vaccinationStatus, record: record)
	}
}
