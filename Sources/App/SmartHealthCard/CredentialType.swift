import Foundation

extension SmartHealthCard.Payload.VerifiableCredential {
	/// The types of credential we support.
	public enum CredentialType: String, Codable {
		public init?(rawValue: String) {
			switch rawValue {
				case "https://smarthealth.cards#health-card":
					self = .healthCard
				case "https://smarthealth.cards#covid19":
					self = .covid19
				case "https://smarthealth.cards#immunization":
					self = .immunization
				default:
					self = .other
			}
		}

		public var rawValue: String {
			switch self {
				case .healthCard:
					return "https://smarthealth.cards#health-card"
				case .covid19:
					return "https://smarthealth.cards#covid19"
				case .immunization:
					return "https://smarthealth.cards#immunization"
				case .other:
					return ""
			}
		}

		public typealias RawValue = String

		/// A VC designed to convey a "Health Card" (i.e. clinical data bound to a subject's identity).
		case healthCard
		/// A Health Card designed to convey COVID-19 details.
		case covid19
		/// A Health Card designed to convey immunization details.
		case immunization
		/// A catchall health card type.
		case other
	}
}

