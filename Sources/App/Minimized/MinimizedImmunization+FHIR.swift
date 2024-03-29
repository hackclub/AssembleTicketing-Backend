import Foundation
import ModelsR4

extension Minimized.Immunization {
	init(immunization: Immunization) throws {
		// Status
		guard let status = immunization.status.value else {
			throw FHIRModelErrors.missingStatus
		}

		self.status = status

		// Vaccine code
		guard let vaccineCoding = immunization.vaccineCode.coding else {
			throw FHIRModelErrors.missingVaccineCode
		}

		self.vaccineCodes = try vaccineCoding.map { coding -> VaccineCode in
			guard let system = coding.system?.value?.description, let code = coding.code?.value?.string else {
				throw FHIRModelErrors.missingVaccineCode
			}

			return VaccineCode(system: system, code: code)
		}

		// Occurrence
		self.date = try Date(immunization.occurrence)

		// Lot Number
		self.lotNumber = immunization.lotNumber?.value?.string
	}
}


extension Immunization {
	func minimized() throws -> Minimized.Immunization {
		try .init(immunization: self)
	}
}
