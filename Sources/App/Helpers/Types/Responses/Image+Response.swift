import Foundation
import Vapor
import Fluent
import Sampleable

extension ImageModel: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Image {
		self.image
	}
}

extension Image: Sampleable {
	static var sample: Image {
		Self.init(data: try! Data(contentsOf: Bundle.module.url(forResource: "icon", withExtension: "png")!), mimeType: .png)
	}
}
