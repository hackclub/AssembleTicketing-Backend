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

		let vaccinationData = VaccinationData(record)

		// Add the new data
		try await self.$vaccinationData.create(vaccinationData, on: db)

		return .init(status: status, record: record, lastUpdated: vaccinationData.lastModified)
	}
}


extension VaccinationData {
	convenience init(_ record: VaccinationData.Response.RecordType) {
		switch record {
			case .image(let imageData, let fileType):
				self.init(photoData: imageData, photoType: fileType)
			case .verified(let verifiedRecord):
				self.init(verifiedVaccination: verifiedRecord)
		}
	}

	var record: VaccinationData.Response.RecordType? {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageVaccination = self.photoData, let imageType = self.photoType {
			return .image(data: imageVaccination, filetype: imageType)
		}
		return nil
	}
}
