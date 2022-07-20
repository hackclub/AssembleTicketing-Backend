import Foundation
import ModelsR4

extension Date {
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
