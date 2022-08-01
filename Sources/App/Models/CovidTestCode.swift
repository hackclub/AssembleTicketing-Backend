import Fluent
import Vapor

/// A COVID Test submission code.
final class CovidTestCode: Model, Content {
	static let schema = "covid_test_codes"

	/// The internal ID of the test .
	@ID(key: .id)
	var id: UUID?

	/// The associated user.
	@Parent(key: "user_id")
	var user: User

	/// The user-facing code.
	@Field(key: "user_facing_code")
	var userFacingCode: String

	/// The date on which the test code was issued.
	@Field(key: "issue_date")
	var issued: Date

	init() { }

	init(id: UUID? = nil, userFacingCode: String) {
		self.id = id
		self.userFacingCode = userFacingCode
		self.issued = Date()
	}
}

