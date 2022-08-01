import Fluent
import Foundation

extension User {
	/// Updates a user and returns a VaccinationResponse in one fell swoop
	func update(status: VerificationStatus, record: VaccinationData.Response.RecordType, on db: Database) async throws -> VaccinationData.Response {
		self.vaccinationStatus = status

		try await self.save(on: db)
		// Make sure we don't have two vaccination records for a user
		if let oldVaccinationData = try await self.$vaccinationData.get(on: db) {
			try await oldVaccinationData.delete(on: db)
		}

		let vaccinationData = try VaccinationData(record)

		// Add the new data
		try await self.$vaccinationData.create(vaccinationData, on: db)

		return .init(status: status, record: record, lastUpdated: vaccinationData.lastModified)
	}
}


extension VaccinationData {
	convenience init(_ record: Response.RecordType) throws {
		switch record {
			case .image(let image):
				self.init()
				self.$image.id = try image.requireID()
				self.lastModified = Date()
			case .verified(let record):
				self.init(verifiedVaccination: record)
		}
	}
}
