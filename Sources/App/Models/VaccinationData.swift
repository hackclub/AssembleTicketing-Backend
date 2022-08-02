import Vapor
import Fluent

/// A record of a COVID vaccination.
final class VaccinationData: ModelStatusEncodable {
	static var parentStatusPath: KeyPath<User, User.VerificationStatus> = \.vaccinationStatus

	static var parentPath: KeyPath<VaccinationData, ParentType> = \.user

	typealias ParentType = User

	typealias StatusType = User.VerificationStatus

	static let schema = "vaccination_data"

	@ID(key: .id)
	/// The internal ID of the user.
	var id: UUID?

	@Parent(key: "user_id")
	var user: User

	/// The image object, if it exists for this. 
	@OptionalParent(key: "image_id")
	var image: Image?

	/// The user's vaccine card, if provided.
	@Field(key: "card_photo")
	var photoData: Data?

	/// The card's MIME type, if applicable.
	@Field(key: "card_photo_type")
	var photoType: HTTPMediaType?

	/// The user's verified vaccination, if provided.
	@Field(key: "verified_vaccination")
	var verifiedVaccination: Minimized.VerifiedVaccinationRecord?

	/// The date on which the vaccination was last modified.
	@Field(key: "modified_date")
	var lastModified: Date

	init() { }

	init(id: UUID? = nil, verifiedVaccination: Minimized.VerifiedVaccinationRecord) {
		self.id = id
		self.verifiedVaccination = verifiedVaccination
		self.lastModified = Date()
		self.photoType = nil
	}

	init(id: UUID? = nil, photoData: Data, photoType: HTTPMediaType) {
		self.id = id
		self.photoData = photoData
		self.photoType = photoType
		self.lastModified = Date()
	}
}
