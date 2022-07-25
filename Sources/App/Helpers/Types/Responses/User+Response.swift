import Vapor

extension User {
	/// A version of User meant to be sent over the wire with a VaccinationResponse.
	struct Response: Content {
		var id: UUID
		var name: String
		var email: String
		@available(*, deprecated)
		var vaccinationData: VaccinationData.Response?

		/// Creates a Response from a User. Will include vaccination data if eager-loaded.
		init(_ user: User) throws {
			self.id = try user.requireID()
			self.name = user.name
			self.email = user.email

			// Weird double-question-mark to handle loading (only send the value if pre-loaded)
			if let wrappedVaccinationData = user.$vaccinationData.value, let vaccinationData = wrappedVaccinationData, let record = vaccinationData.record {
				self.vaccinationData = .init(status: user.vaccinationStatus, record: record, lastUpdated: vaccinationData.lastModified)
			}
		}
	}

	/// Get a response object for the current user.
	func response() throws -> Response {
		return try .init(self)
	}
}

