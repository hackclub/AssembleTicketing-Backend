import Vapor
import FluentKit

extension User: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Response {
		try await .init(self)
	}

	/// A version of User meant to be sent over the wire with a VaccinationResponse.
	struct Response: Content, ResponseHashable {
		static var anyExample: Codable {
			User.Response(id: UUID(), name: "Charlie Welsh", email: "charlie@summer.hackclub.com")
		}

		func sha256() -> Data {
			var hasher = SHA256()

			let nameData = Data(name.utf8)
			let emailData = Data(email.utf8)

			hasher.update(data: nameData)
			hasher.update(data: emailData)

			let hashed = hasher.finalize()
			let hashedBytes = hashed.compactMap { UInt8($0) }
			let data = Data(hashedBytes)

			return data
		}

		var id: UUID
		var name: String
		var email: String
		var waiverStatus: WaiverStatus?

		private init(id: UUID, name: String, email: String, waiverStatus: WaiverStatus? = nil) {
			self.id = id
			self.name = name
			self.email = email
			self.waiverStatus = waiverStatus
		}

		/// Creates a Response from a User. Will include vaccination data if eager-loaded.
		init(_ user: User) async throws {
			self.id = try user.requireID()
			self.name = user.name
			self.email = user.email
			self.waiverStatus = user.waiverStatus
		}
	}
}

