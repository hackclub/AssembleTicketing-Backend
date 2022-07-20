import Foundation
import Vapor

extension Minimized {
	/// The bare minimum we need to know that someone's vaccination status is good.
	struct VerifiedVaccinationRecord: Content {
		/// The issuer of the record.
		var issuer: Issuer
		/// The name of the patient.
		var name: String
		/// The date of the second dose (required for full vaccination).
		var secondShotDate: Date
	}
}
