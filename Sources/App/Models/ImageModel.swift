import Vapor
import Fluent

// In future, we should consider writing a filesystem or object storage-based
// ImageStorage-conformant type.
/// Storage for an Image that resides in the database.
final class ImageModel: Model {
	static let schema = "images"

	/// The internal ID of the image.
	@ID(key: .id)
	var id: UUID?

	/// The data of the image.
	@Field(key: .data)
	private var data: Data

	/// The type of the image.
	@Field(key: .mimeType)
	private var mimeType: HTTPMediaType

	init() { }

	convenience init(id: UUID? = nil, image: Image) {
		self.init()
		self.id = id
		self.image = image
	}
}

extension ImageModel: ImageStorage, Content {
	var image: Image {
		get {
			.init(data: data, mimeType: mimeType)
		} set {
			self.mimeType = newValue.mimeType
			self.data = newValue.data
		}
	}
}

/// A protocol for objects that serve as a backing store for an Image.
protocol ImageStorage {
	/// A computed property that can be used to get or set an image to/from the backing store.
	var image: Image { get set }
}

/// A piece of image data, tagged with the appropriate MIME type.c
struct Image: Content {
	/// The image's data.
	var data: Data
	/// The image's MIME type.
	var mimeType: HTTPMediaType
}
