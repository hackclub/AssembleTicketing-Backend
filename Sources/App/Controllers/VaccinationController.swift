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

	func create(req: Request) async throws -> VerifiedVaccinationRecord {
		let healthCard = try req.content.decode(HealthCardData.self)

		var payload: SmartHealthCard.Payload
		var name: String

		if let qr = healthCard.qr {
			(name, payload) = try await SmartHealthCard.verify(qr: qr)
		} else if let qrChunks = healthCard.qrChunks {
			(name, payload) = try await SmartHealthCard.verify(qrChunks: qrChunks)
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
							continue
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

		immunizationModels.sort { lhs, rhs in
			lhs.date < rhs.date
		}

		return VerifiedVaccinationRecord(
			issuer: VaccinationIssuer(
				name: name,
				url: payload.issuer
			),
			name: patientModel.names.joined(separator: " "),
			mostRecentDose: immunizationModels.last!.date
		)
	}
}

extension SmartHealthCard.Payload: Content { }

struct VaccinationIssuer: Content {
	var name: String
	var url: URL
}

struct VerifiedVaccinationRecord: Content {
	/// The issuer of the record.
	var issuer: VaccinationIssuer
	/// The name of the patient.
	var name: String
	/// The date of the most recent dose.
	var mostRecentDose: Date
}
