import Vapor

/// An enum with cases for generic verification statuses.
enum VerificationStatus: String, Codable {
	/// Verification is complete.
	case verified
	/// Verification worked but there's some discrepancy a human has to look at (generally a name).
	case verifiedWithDiscrepancy
	/// Automatic verification doesn't work (generally the upload was an image).
	case humanReviewRequired
	/// The vaccination record was explicitly denied by a human.
	case denied

	/// Helper property to determine if a status counts as 'verified'.
	var isVerified: Bool {
		switch self {
			case .verified:
				return true
			default:
				return false
		}
	}
}

extension VerificationStatus: Comparable {
	/// For Comparable conformance.
	var intValue: Int {
		switch self {
			case .verified:
				return 3
			case .verifiedWithDiscrepancy:
				return 2
			case .humanReviewRequired:
				return 1
			case .denied:
				return 0
		}
	}

	static func < (lhs: VerificationStatus, rhs: VerificationStatus) -> Bool {
		lhs.intValue < rhs.intValue
	}
}

/// A Content-conforming struct used to decode status-update responses from the client.
struct StatusUpdate: Content {
	static var anyExample: Codable = StatusUpdate(status: .verified)

	/// The status to update.
	var status: VerificationStatus
}
