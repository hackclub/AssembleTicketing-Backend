import Foundation
import Vapor

extension Minimized {
	/// A model that represents an abridged FHIR Patient object.
	struct Patient: Content {
		/// The name(s) of the patient, in order.
		var names: [String]
		/// The date of birth of the patient.
		var birthDate: Date
	}
}
