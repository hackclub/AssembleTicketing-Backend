import ModelsR4
import Vapor

/// A container struct for the various minimized types.
struct Minimized {}

extension ModelsR4.Bundle {
	func minify() throws -> Minimized.HealthRecord {
		var minimizedPatient: Minimized.Patient?
		var minimizedImmunizations: [Minimized.Immunization] = []
		var immunizationReference: Reference?

		if let entries = self.entry {
			for entry in entries {
				if let resource = entry.resource {
					switch resource {
						case .patient(let patient):
							let names = patient.name!
							guard let birthDate = try patient.birthDate?.value?.asNSDate() else {
								throw Abort(.badRequest, reason: "Invalid patient birth date.")
							}
							var nameStrings = [String]()

							for name in names {
								var givenNameString: String? = nil

								if let givenName = name.given {
									givenNameString = givenName.map({ string in
										string.value!.string
									}).joined(separator: " ")
								}

								let familyName = name.family?.value?.string

								if let givenName = givenNameString, let familyName = familyName {
									nameStrings.append(contentsOf: [givenName, familyName])
								} else if let givenName = givenNameString {
									nameStrings.append(givenName)
								} else if let familyName = familyName {
									nameStrings.append(familyName)
								}
							}

							minimizedPatient = Minimized.Patient(names: nameStrings, birthDate: birthDate)

						case .immunization(let immunization):
							// Don't bother adding incomplete vaccinations.
							guard immunization.status.value == .completed else {
								continue
							}

							// Handle checking that there aren't multiple references.
							if let immunizationReference = immunizationReference {
								guard immunizationReference.reference == immunization.patient.reference else {
									throw Abort(.badRequest, reason: "Immunizations reference multiple patients.")
								}
							} else {
								immunizationReference = immunization.patient
							}

							minimizedImmunizations.append(try Minimized.Immunization(immunization: immunization))
						default:
							continue
					}

				}
			}
		}

		guard let minimizedPatient = minimizedPatient else {
			throw Abort(.badRequest, reason: "No patient given.")
		}

		return Minimized.HealthRecord(patient: minimizedPatient, immunizations: minimizedImmunizations)
	}
}

