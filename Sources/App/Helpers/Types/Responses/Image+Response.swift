import Foundation
import Vapor
import Fluent

extension ImageModel: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Image {
		self.image
	}
}

extension Image {
	static var anyExample: Codable {
		Self.init(data: try! Data(contentsOf: Bundle.module.url(forResource: "icon", withExtension: "png")!), mimeType: .png)
	}
}
