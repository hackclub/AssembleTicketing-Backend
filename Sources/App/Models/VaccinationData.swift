import Vapor
import Fluent

/// A user of the Assemble ticketing system.
final class VaccinationData: Model, Content {
	static let schema = "vaccination_data"

	@ID(key: .id)
	/// The internal ID of the user.
	var id: UUID?

	@Parent(key: "user_id")
	var user: User

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
	}

	init(id: UUID? = nil, photoData: Data, photoType: HTTPMediaType) {
		self.id = id
		self.photoData = photoData
		self.photoType = photoType
		self.lastModified = Date()
	}
}
