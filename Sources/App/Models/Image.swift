import Vapor
import Fluent

/// An image for other types to make a parent they can save on.
final class Image: Model, Content {
	static let schema = "images"

	/// The internal ID of the user.
	@ID(key: .id)
	var id: UUID?

	/// The data of the photo.
	@Field(key: "photo_data")
	var data: Data

	/// The type of the photo.
	@Field(key: "mime_type")
	var mimeType: HTTPMediaType

	init() { }

	init(id: UUID? = nil, photoData: Data, photoType: HTTPMediaType) {
		self.id = id
		self.data = photoData
		self.mimeType = photoType
	}
}
