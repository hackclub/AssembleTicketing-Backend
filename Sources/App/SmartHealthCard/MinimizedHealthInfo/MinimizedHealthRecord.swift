import Vapor

extension Minimized {
	/// The minimized data of a health record, containing just the patient and the immunizations.
	struct HealthRecord: Content {
		var patient: Minimized.Patient
		var immunizations: [Minimized.Immunization]
	}
}

