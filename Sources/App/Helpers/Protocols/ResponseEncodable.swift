import Foundation
import Vapor
import FluentKit

/// A protocol for types that have an associated response that they can generate.
protocol ResponseEncodable {
	/// The type of the response that response generation methods will return.
	associatedtype Response: Content

	func getResponse(on db: Database) async throws -> Response
}
