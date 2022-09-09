import Foundation
import Fluent

/// A protocol for types that contain a status.
protocol HasStatus: Model {
	/// The status for the type.
	var status: VerificationStatus { get set }
}

/// An enum of types conforming to `HasStatus`.
enum StatusContainer: String, Codable {
	/// A vaccination status.
	case vaccination
	/// A COVID test status.
	case covidTest

	var metatype: any HasStatus.Type {
		switch self {
			case .vaccination:
				return VaccinationData.self
			case .covidTest:
				return CovidTestData.self
		}
	}
}
