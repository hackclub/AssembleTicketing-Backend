import Foundation
import ModelsR4

extension ImmunizationModel {
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
		guard let lotNumber = immunization.lotNumber?.value?.string else {
			throw FHIRModelErrors.missingLotNumber
		}
		self.lotNumber = lotNumber
	}
}

