import Fluent
import Vapor
import Crypto
import JWTKit
import NIOFoundationCompat

struct TestController: Controller, AdminUpdateController, ImageUploadController {
	func createNewModel(req: Vapor.Request) async throws -> CovidTestData {
		let model = CovidTestData(status: .humanReviewRequired)
		try await model.save(on: req.db)
		return model
	}

	func getExistingModel(for user: User, on db: FluentKit.Database) async throws -> CovidTestData? {
		return try await user.$testData.get(on: db)
	}

	func adminUpdate(with update: AdminUpdate, for user: User, on db: FluentKit.Database) async throws -> CovidTestData {
		guard let model = try await getExistingModel(for: user, on: db) else {
			throw Abort(.notFound, reason: "No such COVID test to set status of.")
		}

		model.status = update.status

		try await model.update(on: db)

		return model
	}

	typealias ObjectType = CovidTestData
	typealias AdminUpdate = StatusUpdate

	func boot(routes: RoutesBuilder) throws {
		let tests = routes.grouped("tests")

		try allRoutes(routes: tests)
	}
}
