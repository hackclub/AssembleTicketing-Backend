import Fluent

extension User {
	/// Updates a user and returns a VaccinationResponse in one fell swoop
	func update(status: VaccinationVerificationStatus, record: VaccinationData.Response.RecordType, on db: Database) async throws -> VaccinationData.Response {
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

