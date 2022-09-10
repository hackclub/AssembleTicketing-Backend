import Vapor
import Fluent

/// A record of a COVID vaccination.
final class VaccinationData: Model, ImageAttached, HasStatus {
	static let schema = "vaccination_data"

	@ID(key: .id)
	/// The internal ID of the user.
	var id: UUID?
	/// The user associated with the vaccination.
	@Parent(key: .userID)
	var user: User

	// NOTE: This is an OptionalParent relation so we can have Image be related to multiple types.
	/// The image object, if it exists for this. 
	@OptionalParent(key: .imageID)
	var image: ImageModel?

	@Field(key: .status)
	var status: VerificationStatus

	/// The user's verified vaccination, if provided.
	@Field(key: .verifiedVaccination)
	var verifiedVaccination: Minimized.VerifiedVaccinationRecord?

	/// The date on which the vaccination was last modified.
	@Field(key: .modifiedDate)
	var lastModified: Date

	// Boilerplate to get the actual relation so we can deal with ImageAttached generically.
	var imageRelation: OptionalParentProperty<VaccinationData, ImageModel> {
		self.$image
	}

	init() {
		self.lastModified = Date()
	}

	init(id: UUID? = nil, status: VerificationStatus) {
		self.id = id
		self.lastModified = Date()
		self.status = status
	}
}
