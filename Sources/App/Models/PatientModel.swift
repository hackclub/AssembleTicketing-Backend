import Foundation
import Vapor

/// A model that represents an abridged FHIR Patient object.
struct PatientModel: Content {
	/// The name(s) of the patient.
	var names: [String]
	/// The date of birth of the patient.
	var birthDate: Date
}

