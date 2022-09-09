import Foundation
import Vapor
import Fluent

extension ImageModel: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Image {
		self.image
	}
}
