import Vapor
import Fluent

/// A protocol for models that have images attached.
protocol ImageAttached: Model {
	/// The attached image.
	var imageRelation: OptionalParentProperty<Self, ImageModel> { get }
}

extension ImageAttached {
	/// Sets the attached image model's data (creating one if it doesn't exist) to the given `Image`.
	func setImage(with image: Image, on db: Database) async throws {
		let imageModel = try await self.imageRelation.get(on: db)

		guard let imageModel = imageModel else {
			try await createImage(with: image, on: db)
			return
		}

		imageModel.image = image
		try await imageModel.update(on: db)
	}

	/// Updates an existing attached image with the contents of the provided `Image`.
	func updateImage(with image: Image, on db: Database) async throws {
		guard let imageModel = try await self.imageRelation.get(on: db) else {
			throw Abort(.notFound, reason: "No image attached to \(Self.self)")
		}

		imageModel.image = image

		try await imageModel.update(on: db)
	}

	/// Creates a new attached image on the database with the contents of the provided `Image`.
	func createImage(with image: Image, on db: Database) async throws {
		let imageModel = ImageModel(image: image)
		// Create the image
		try await imageModel.create(on: db)
		// Attach the image
		self.imageRelation.id = try imageModel.requireID()
		// Save the attachment
		try await self.save(on: db)
	}
}

