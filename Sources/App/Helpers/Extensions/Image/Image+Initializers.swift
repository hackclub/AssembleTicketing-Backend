import Vapor

extension Image: FileConvertible {
	static var defaultFilename: String = "image"

	init(from file: File) throws {
		guard let contentType = file.contentType, contentType.type == "image" else {
			throw Abort(.badRequest, reason: "Invalid content type.")
		}

		self.init(data: Data(buffer: file.data), mimeType: contentType)
	}

	var file: File {
		let buffer = ByteBuffer(data: self.data)
		// NOTE: Quick and dirty, but should work for images
		let fileExtension = self.mimeType.subType

		return .init(data: buffer, filename: "\(Self.defaultFilename).\(fileExtension)")
	}
}

/// A protocol describing types that can be converted to and from a Data object and a MIME type without losing any body data.
protocol FileConvertible {
	/// The default filename to use for the type, excluding the extension.
	static var defaultFilename: String { get }

	/// Initialize from a file to the conforming type.
	init(from file: File) throws

	/// The file-converted version of the conforming type.
	var file: File { get }
}

extension File {
	init(_ convertible: FileConvertible) {
		self = convertible.file
	}
}
