import Vapor
import Fluent

/// A protocol for Controllers that support upload of images in the supported formats.
protocol ImageUploadController: Controller where ObjectType: ImageAttached {
	/// A function that gets called when an image is uploaded for a user that doesn't have an instance of `ObjectType` attached.
	/// - Parameters:
	///   - req: The Request instance for the requesting object.
	/// - Returns: A saved instance of `ObjectType`.
	func createNewModel(req: Request) async throws -> ObjectType
}

extension ImageUploadController {
	func uploadImage(_ image: Image, req: Request) async throws -> ObjectType.Response {
		let user = try await req.getUser()

		let existingModel = try await getExistingModel(for: user, on: req.db)
		var model: ObjectType
		if let existingModel = existingModel {
			model = existingModel
		} else {
			model = try await createNewModel(req: req)
		}

		try await model.updateImage(with: image, on: req.db)

		return try await model.getResponse(on: req.db)
	}

	func uploadImageFile(req: Request) async throws -> ObjectType.Response {
		let input = try req.content.decode(File.self)
		let image = try Image(from: input)

		return try await uploadImage(image, req: req)
	}

	func uploadImageBase64(req: Request) async throws -> ObjectType.Response {
		let image = try req.content.decode(Image.self)

		return try await uploadImage(image, req: req)
	}

	/// The image routes, all grouped as one.
	func imageRoutes(_ routes: RoutesBuilder) throws {
		routes.get(use: view)
		routes.get(":hash", use: view)
		let image = routes.grouped("image")
		image.post("base64", use: uploadImageBase64)
		image.post("multipart", use: uploadImageFile)
	}
}

