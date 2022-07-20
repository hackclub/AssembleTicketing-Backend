import Vapor
import Fluent

/// A user of the Assemble ticketing system.
final class User: Model, Content {
	static let schema = "users"

	@ID(key: .id)
	/// The internal ID of the user.
	var id: UUID?

	@Field(key: "name")
	/// The user's name.
	var name: String

	@Field(key: .email)
	/// The user's email.
	var email: String

	@Field(key: "vaccinationStatus")
	var vaccinationStatus: VaccinationVerificationStatus

	@OptionalChild(for: \.$user)
	var vaccinationData: VaccinationData?

	init() { }

	init(id: UUID? = nil, name: String, email: String, vaccinationStatus: VaccinationVerificationStatus) {
		self.id = id
		self.name = name
		self.email = email
		self.vaccinationStatus = vaccinationStatus
	}

	enum VaccinationVerificationStatus: String, Codable {
		/// Verification is complete.
		case verified
		/// Verification worked but there's some discrepancy a human has to look at (generally a name).
		case verifiedWithDiscrepancy
		/// Automatic verification doesn't work (generally the upload was an image).
		case humanReviewRequired
		/// No data was uploaded.
		case noData
		/// The vaccination record was explicitly denied by a human.
		case denied
	}
}


extension FieldKey {
	static let email: FieldKey = "email"
}
