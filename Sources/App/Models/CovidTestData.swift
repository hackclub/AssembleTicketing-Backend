import Vapor
import Fluent

/// A COVID Test record.
final class CovidTestData: ModelStatusEncodable, ResponseEncodable {
	static var parentStatusPath: KeyPath<User, User.VerificationStatus> = \.testStatus

	static var parentPath: KeyPath<CovidTestData, ParentType> = \.user

	typealias ParentType = User

	typealias StatusType = User.VerificationStatus

	func getResponse(on db: Database) async throws -> Response {
		let user = self.getParent(on: db)
		let status = self.getStatus(from: user)

		return try await .init(
			status: status,
			image: self.$image.get(on: db).getResponse(on: db),
			lastUpdated: self.lastModified
		)
	}

	static let schema = "covid_test_data"

	/// The internal ID of the user.
	@ID(key: .id)
	var id: UUID?

	/// The associated user.
	@Parent(key: "user_id")
	var user: User

	/// The associated image.
	@Parent(key: "image_id")
	var image: Image

	/// The date on which the test was last modified.
	@Field(key: "modified_date")
	var lastModified: Date

	init() { }

	init(id: UUID? = nil) {
		self.id = id
		self.lastModified = Date()
	}
}
