import Vapor

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

