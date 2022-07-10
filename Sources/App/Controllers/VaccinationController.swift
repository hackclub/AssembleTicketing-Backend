import Fluent
import Vapor
import SWCompression
import Crypto
import JWTKit
import ModelsR4

struct VaccinationController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let vaccinations = routes.grouped("vaccinations")
        vaccinations.post(use: create)
    }

	struct HealthCardReturn: Content {
		var headers: String
		var body: String
		var signature: String
	}

	struct HealthCardData: Content {
		var qr: String?
		var qrChunks: [String]?
	}

	func create(req: Request) async throws -> SmartHealthCard.Payload {
		let healthCard = try req.content.decode(HealthCardData.self)

		var payload: SmartHealthCard.Payload

		if let qr = healthCard.qr {
			payload = try await SmartHealthCard.verify(qr: qr)
		} else if let qrChunks = healthCard.qrChunks {
			payload = try await SmartHealthCard.verify(qrChunks: qrChunks)
		} else {
			throw Abort(.badRequest, reason: "Specify chunks or single QR code.")
		}

		guard payload.verifiableCredential.type.contains(.covid19) &&
				payload.verifiableCredential.type.contains(.immunization) &&
				payload.verifiableCredential.type.contains(.healthCard) else {
			throw Abort(.badRequest, reason: "Wrong type of health card.")
		}

		var patientModel: PatientModel? = nil
		var immunizationModels = [ImmunizationModel]()

		var immunizationReference: Reference? = nil

		if let entries = payload.verifiableCredential.credentialSubject.fhirBundle.entry {
			for entry in entries {
				if let resource = entry.resource {
					switch resource.resourceType {
						case "Patient":
							guard patientModel == nil else {
								throw Abort(.badRequest, reason: "Multiple patients in request.")
							}

							guard let patient = resource.get(if: Patient.self) else {
								throw Abort(.badRequest, reason: "Record marked as Patient was not.")
							}

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
									nameStrings.append("\(givenName), \(familyName)")
								} else if let givenName = givenNameString {
									nameStrings.append(givenName)
								} else if let familyName = familyName {
									nameStrings.append(familyName)
								}
							}

							patientModel = PatientModel(names: nameStrings, birthDate: birthDate)

						case "Immunization":
							guard let immunization = resource.get(if: Immunization.self) else {
								throw Abort(.badRequest, reason: "Record marked as Immunization was not.")
							}

							// Handle checking that there aren't multiple references.
							if let immunizationReference = immunizationReference {
								guard immunizationReference.reference == immunization.patient.reference else {
									throw Abort(.badRequest, reason: "Immunizations reference multiple patients.")
								}
							} else {
								immunizationReference = immunization.patient
							}

							immunizationModels.append(try ImmunizationModel(immunization: immunization))
						default:
							print(resource.resourceType)
					}
				}
			}
		}

		guard let patientModel = patientModel else {
			throw Abort(.badRequest, reason: "No patient given in card.")
		}

		guard immunizationModels.count >= 2 else {
			throw Abort(.badRequest, reason: "Not enough immunizations against COVID-19.")
		}

		return payload
	}
}

extension SmartHealthCard.Payload: Content { }
