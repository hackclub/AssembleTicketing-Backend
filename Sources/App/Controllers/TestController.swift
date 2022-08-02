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

struct TestController: RouteCollection {
	func boot(routes: RoutesBuilder) throws {
		let authed = routes.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])
		// Also allows cookie-based auth
		let cookieAuthed = routes.grouped([AccessToken.cookieAcceptingAuthenticator(), AccessToken.guardMiddleware()])

		let vaccinations = authed.grouped("tests")
		vaccinations.post(["image", "multipart"], use: uploadImage)

		// Cookie supported routes
		let cookieVaccinations = cookieAuthed.grouped("tests")
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

	struct AdminUpdate: Content {
		var newStatus: User.VerificationStatus
	}

	/// Allows an admin to set a user's vaccination status manually (e.g, for `humanReviewRequired`).
	/// - Returns: A `VaccinationData.Response` object with the user's new vaccination data.
	func adminSet(req: Request) async throws -> CovidTestData.Response {
		let update = try req.content.decode(AdminUpdate.self)

		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}

		guard let testData = try await user.$testData.get(on: req.db) else {
			throw Abort(.notFound, reason: "That user hasn't uploaded any test data.")
		}

		// Update the status and modification date.
		user.testStatus = update.newStatus
		testData.lastModified = Date()

		try await user.save(on: req.db)

		let image = try await testData.$image.get(on: req.db)

		return .init(status: user.testStatus, image: try await image.getResponse(on: req.db), lastUpdated: testData.lastModified)
	}

	/// Allows an admin to get more detailed information about a user (including vaccination data).
	func adminGet(req: Request) async throws -> CovidTestData.Response {
		guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
			throw Abort(.notFound, reason: "There's no user with that ID.")
		}

		guard let testData = try await user.$testData.get(on: req.db) else {
			throw Abort(.notFound, reason: "That user hasn't uploaded any test data.")
		}

		let image = try await testData.$image.get(on: req.db)

		return .init(status: user.testStatus, image: try await image.getResponse(on: req.db), lastUpdated: testData.lastModified)
	}

	func uploadImageBase64(req: Request) async throws -> CovidTestData.Response {
		let user = try await req.getUser()
		let input = try req.content.decode(Image.Response.self)

		guard input.mimeType.type == "image" else {
			throw Abort(.badRequest, reason: "Must be an image.")
		}

		let image = try Image(from: input)
		try await image.save(on: req.db)

		let updatedTestData = CovidTestData()
		updatedTestData.$image.id = try image.requireID()
		updatedTestData.lastModified = Date()

		if let existing = try await user.$testData.get(on: req.db) {
			try await existing.delete(on: req.db)
		}

		try await user.$testData.create(updatedTestData, on: req.db)

		user.testStatus = .humanReviewRequired
		try await user.save(on: req.db)

		return .init(status: user.testStatus, image: try await image.getResponse(on: req.db), lastUpdated: Date())
	}

	func uploadImage(req: Request) async throws -> CovidTestData.Response {
		let user = try await req.getUser()
		let input = try req.content.decode(File.self)

		let image = try Image(from: input)
		try await image.save(on: req.db)

		let updatedTestData = CovidTestData()
		updatedTestData.$image.id = try image.requireID()
		updatedTestData.lastModified = Date()

		if let existing = try await user.$testData.get(on: req.db) {
			try await existing.delete(on: req.db)
		}

		try await user.$testData.create(updatedTestData, on: req.db)

		user.testStatus = .humanReviewRequired
		try await user.save(on: req.db)

		return .init(status: user.testStatus, image: try await image.getResponse(on: req.db), lastUpdated: Date())
	}

	func view(req: Request) async throws -> CovidTestData.Response {
		let user = try await req.getUser()

		guard let testData = try await user.$testData.get(on: req.db) else {
			throw Abort(.notFound, reason: "No test data available.")
		}

		let image = try await testData.$image.get(on: req.db)

		let response = CovidTestData.Response(status: user.testStatus, image: try await image.getResponse(on: req.db), lastUpdated: testData.lastModified)

		guard !response.isEquivalent(from: req.parameters.get("hash")) else {
			throw Abort(.notModified, reason: "Data not modified.")
		}

		return response
	}
}
