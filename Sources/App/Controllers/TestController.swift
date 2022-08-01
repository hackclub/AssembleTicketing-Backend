import Fluent
import Vapor
import Crypto
import JWTKit
import NIOFoundationCompat


extension Image {
	/// A garden-variety image upload object. It contains the data and a MIME type.
	struct Upload: Content {
		/// The data of the image.
		var data: Data
		/// The upload type of the image.
		var imageType: HTTPMediaType
	}
}
//
//struct TestController: RouteCollection {
//	func boot(routes: RoutesBuilder) throws {
//		let authed = routes.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
//		// Also allows cookie-based auth
//		let cookieAuthed = routes.grouped([AccessToken.cookieAcceptingAuthenticator(), AccessToken.guardMiddleware()])
//
//		let vaccinations = authed.grouped("tests")
//		vaccinations.post(["image", "multipart"], use: uploadImage)
//
//		// Cookie supported routes
//		let cookieVaccinations = cookieAuthed.grouped("vaccinations")
//		cookieVaccinations.get(use: view)
//		cookieVaccinations.get(":hash", use: view)
//		cookieVaccinations.post(["image", "base64"], use: uploadImageBase64)
//
//		// Admin routes
//		let admin = vaccinations
//			.grouped(EnsureAdminUserMiddleware())
//			.grouped("admin")
//
//		admin.group(":userID") { vaccination in
//			vaccination.post("status", use: adminSet)
//			vaccination.get(use: adminGet)
//			vaccination.get(":hash", use: adminGet)
//		}
//	}
//
//	struct AdminVaccinationUpdate: Content {
//		var newStatus: User.TestVerificationStatus
//	}
//
//	/// Allows an admin to set a user's vaccination status manually (e.g, for `humanReviewRequired`).
//	/// - Returns: A `VaccinationData.Response` object with the user's new vaccination data.
//	func adminSet(req: Request) async throws -> CovidTestData.Response {
//		let update = try req.content.decode(AdminVaccinationUpdate.self)
//
//		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
//			throw Abort(.notFound, reason: "There's no user with that ID.")
//		}
//
//		guard let testData = try await user.$testData.get(on: req.db) else {
//			throw Abort(.notFound, reason: "That user hasn't uploaded any test data.")
//		}
//
//		guard let testCode = try await user.$submissionCode.get(on: req.db) else {
//			throw Abort(.notFound, reason: "No submission code has been issued.")
//		}
//
//		// Update the status and modification date.
//		user.testStatus = update.newStatus
//		testData.lastModified = Date()
//
//		try await user.save(on: req.db)
//
//		return .init(status: user.testStatus, image: testData.image, lastUpdated: testData.lastModified, code: testCode.userFacingCode)
//	}
//
//	/// Allows an admin to get more detailed information about a user (including vaccination data).
//	func adminGet(req: Request) async throws -> CovidTestData.Response {
//		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
//			throw Abort(.notFound, reason: "There's no user with that ID.")
//		}
//
//		guard let testData = try await user.$testData.get(on: req.db) else {
//			throw Abort(.notFound, reason: "That user hasn't uploaded any test data.")
//		}
//
//		guard let testCode = try await user.$submissionCode.get(on: req.db) else {
//			throw Abort(.notFound, reason: "No submission code has been issued.")
//		}
//
//		return .init(status: user.testStatus, image: testData.image, lastUpdated: testData.lastModified, code: testCode.userFacingCode)
//	}
//
//	struct Base64Image: Content {
//		var mimeType: HTTPMediaType
//		var data: Data
//
//		var image: CovidTestData.Image {
//			CovidTestData.Image.init(imageData: data, imageType: mimeType)
//		}
//	}
//
//	func uploadImageBase64(req: Request) async throws -> CovidTestData.Response {
//		let user = try await req.getUser()
//		let input = try req.content.decode(Base64Image.self)
//
//		guard input.mimeType.type == "image" else {
//			throw Abort(.badRequest, reason: "Must be an image.")
//		}
//
//		guard let submissionCode = try await user.$submissionCode.get(on: req.db) else {
//			throw Abort(.notFound, reason: "No submission code has been issued.")
//		}
//
//		let codeIssuanceTimeInterval = submissionCode.issued.timeIntervalSinceNow
//
//		// TODO: Make expiry configurable
//		guard (60 * 15) < codeIssuanceTimeInterval || codeIssuanceTimeInterval < 0 else {
//			throw Abort(.badRequest, reason: "Submission code expired. Go get a new one.")
//		}
//
//		let updatedTestData = CovidTestData(photoData: input.data, photoType: input.mimeType)
//
//		if let existing = try await user.$testData.get(on: req.db) {
//			try await existing.delete(on: req.db)
//		}
//
//		try await user.$testData.create(updatedTestData, on: req.db)
//
//		return .init(status: user.testStatus, image: input.image, lastUpdated: Date(), code: submissionCode.userFacingCode)
//	}
//
//	func uploadImage(req: Request) async throws -> CovidTestData.Response {
//		let user = try await req.getUser()
//		let input = try req.content.decode(Base64Image.self)
//
//		guard input.mimeType.type == "image" else {
//			throw Abort(.badRequest, reason: "Must be an image.")
//		}
//
//		guard let submissionCode = try await user.$submissionCode.get(on: req.db) else {
//			throw Abort(.notFound, reason: "No submission code has been issued.")
//		}
//
//		let codeIssuanceTimeInterval = submissionCode.issued.timeIntervalSinceNow
//
//		// TODO: Make expiry configurable
//		guard (60 * 15) < codeIssuanceTimeInterval || codeIssuanceTimeInterval < 0 else {
//			throw Abort(.badRequest, reason: "Submission code expired. Go get a new one.")
//		}
//
//		let updatedTestData = CovidTestData(photoData: input.data, photoType: input.mimeType)
//
//		if let existing = try await user.$testData.get(on: req.db) {
//			try await existing.delete(on: req.db)
//		}
//
//		try await user.$testData.create(updatedTestData, on: req.db)
//
//		return .init(status: user.testStatus, image: input.image, lastUpdated: Date(), code: submissionCode.userFacingCode)
//	}
//
//	func view(req: Request) async throws -> CovidTestData.Response {
//		let user = try await req.getUser()
//
//		guard let vaccinationData = try await user.$vaccinationData.get(on: req.db) else {
//			throw Abort(.notFound, reason: "You haven't uploaded a vaccination yet.")
//		}
//
//		guard let vaccinationRecord = vaccinationData.record else {
//			throw Abort(.notFound, reason: "There was no data in your vaccination record.")
//		}
//
//		let response = VaccinationData.Response(status: user.vaccinationStatus, record: vaccinationRecord, lastUpdated: Date())
//
//		if let hash = req.parameters.get("hash") {
//			guard response.sha256().base64URLEncodedString() == hash else {
//				throw Abort(.notModified, reason: "Data not modified.")
//			}
//		}
//
//		return response
//	}
//}
