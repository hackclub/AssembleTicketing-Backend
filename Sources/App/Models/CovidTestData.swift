import Vapor
import Fluent

/// A COVID Test record.
final class CovidTestData: Model, ImageAttached, ResponseEncodable {
	static let schema = "covid_test_data"

	/// The internal ID of the user.
	@ID(key: .id)
	var id: UUID?

	/// The associated user.
	@Parent(key: .userID)
	var user: User

	// NOTE: This is a Parent relation so we can have Image be related to multiple types.
	/// The associated image.
	@OptionalParent(key: .imageID)
	var image: ImageModel?

	/// The VerificationStatus for the test.
	@Field(key: .status)
	var status: VerificationStatus

	/// The date on which the test was last modified.
	@Field(key: .modifiedDate)
	var lastModified: Date

	// Boilerplate to get the actual relation so we can deal with ImageAttached generically.
	var imageRelation: OptionalParentProperty<CovidTestData, ImageModel> {
		self.$image
	}

	init() { }

	init(id: UUID? = nil, status: VerificationStatus) {
		self.id = id
		self.status = status
		self.lastModified = Date()
	}
}
