import Vapor
import Fluent

/// A user of the Assemble ticketing system.
final class User: Model {
	static let schema = "users"

	@ID(key: .id)
	/// The internal ID of the user.
	var id: UUID?

	@Field(key: .name)
	/// The user's name.
	var name: String

	@Field(key: .email)
	/// The user's email.
	var email: String

	@Field(key: .checkInStatus)
	var isCheckedIn: Bool

	@Field(key: .waiverStatus)
	var waiverStatus: WaiverStatus?

	@OptionalChild(for: \.$user)
	var vaccinationData: VaccinationData?	

	@OptionalChild(for: \.$user)
	var testData: CovidTestData?

	/// An enum with cases for the various states of checked in a user can be.
	enum CheckInStatus: String {
		/// The user isn't checked in.
		case notCheckedIn
		/// The user isn't checked in, but a ticket has been issued.
		case ticketIssued
		/// The user has been checked in.
		case checkedIn

		/// A boolean describing whether the user counts as checked in or not.
		var isCheckedIn: Bool {
			switch self {
				case .checkedIn:
					return true
				default:
					return false
			}
		}
	}

	/// An enum with cases for the various types of waiver a user can have submitted.
	enum WaiverStatus: String, Codable {
		/// The mandatory waiver everyone has to sign.
		case mandatory
		/// The freedom waiver.
		case freedom
	}


	init() { }

	init(id: UUID? = nil, name: String, email: String) {
		self.id = id
		self.name = name
		self.email = email
	}
}
