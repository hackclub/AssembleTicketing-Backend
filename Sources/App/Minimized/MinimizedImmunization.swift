import Foundation
import ModelsR4
import Vapor

extension Minimized {
	/// A model that represents an abridged FHIR Immunization object.
	struct Immunization: Content {
		/// The status of the immunization.
		var status: EventStatus
		/// The vaccine code(s) of the immunization given.
		var vaccineCodes: [VaccineCode]
		/// The date the immunization was given on.
		var date: Date
		/// The lot number of the vaccine (if available).
		var lotNumber: String?

		/// A representation of a vaccine code.
		struct VaccineCode: Content {
			/// The URI of a vaccine coding system.
			var system: String
			/// The code of the vaccine.
			var code: String
		}
	}
}
