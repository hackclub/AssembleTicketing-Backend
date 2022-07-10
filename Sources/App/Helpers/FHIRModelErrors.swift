import Foundation

/// A set of errors that can arise when setting up an FHIR model.
enum FHIRModelErrors: Error {
	/// A date value wasn't provided.
	case missingDate
	/// The date provided was in the wrong format.
	case wrongDateFormat
	/// A status value wasn't provided.
	case missingStatus
	/// The vaccine code information wasn't provided.
	case missingVaccineCode
	/// The lot number wasn't provided.
	case missingLotNumber
}
