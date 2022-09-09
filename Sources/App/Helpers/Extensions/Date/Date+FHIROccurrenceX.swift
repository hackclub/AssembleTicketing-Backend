import Foundation
import ModelsR4

extension Date {
	/// Initialize a Date from an FHIR Immunization.OccurenceX.
	init(_ fhirOccurence: Immunization.OccurrenceX) throws {
		switch fhirOccurence {
			case .dateTime(let datetime):
				guard let dateValue = datetime.value else {
					throw FHIRModelErrors.missingDate
				}

				self = try dateValue.asNSDate()
			case .string:
				throw FHIRModelErrors.missingDate
		}
	}
}
