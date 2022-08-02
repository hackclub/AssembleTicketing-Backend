import Foundation
import Vapor
import Fluent

extension Image: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Response {
		return .init(mimeType: self.mimeType, data: self.data)
	}

	struct Response: Content {
		/// The type of the image.
		var mimeType: HTTPMediaType
		/// The image's data.
		var data: Data
	}
}
