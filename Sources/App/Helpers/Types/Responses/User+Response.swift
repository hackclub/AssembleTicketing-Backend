import Vapor
import FluentKit

extension User: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Response {
		try await .init(self, on: db)
	}

	/// A version of User meant to be sent over the wire with a VaccinationResponse.
	struct Response: Content {
		var id: UUID
		var name: String
		var email: String
		@available(*, deprecated)
		var vaccinationData: VaccinationData.Response?

		/// Creates a Response from a User. Will include vaccination data if eager-loaded.
		init(_ user: User, on database: Database) async throws {
			self.id = try user.requireID()
			self.name = user.name
			self.email = user.email

			// Weird double-question-mark to handle loading (only send the value if pre-loaded)
			if let wrappedVaccinationData = user.$vaccinationData.value, let vaccinationData = wrappedVaccinationData {
				let record = try await vaccinationData.getRecord(on: database)
				self.vaccinationData = .init(status: user.vaccinationStatus, record: record, lastUpdated: vaccinationData.lastModified)
			}
		}
	}
}

