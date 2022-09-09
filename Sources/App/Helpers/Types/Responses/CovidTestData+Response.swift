import Vapor
import Fluent

extension CovidTestData: ResponseEncodable {
	struct Response: Content, ResponseHashable {
		func sha256() -> Data {
			var hasher = SHA256()

			let imageData = image.data
			// Convert the status type name to a UTF-8 blob of data
			let statusData = Data(status.rawValue.utf8)
			// Convert the time to second-based UNIX epoch time and the convert that to data
			var intLastModified = Int(self.lastUpdated.timeIntervalSince1970)
			let lastModifiedData = Data(
				bytes: &intLastModified,
				count: MemoryLayout.size(ofValue: intLastModified)
			)

			hasher.update(data: imageData)
			hasher.update(data: statusData)
			hasher.update(data: lastModifiedData)
			let hashed = hasher.finalize()
			let hashedBytes = hashed.compactMap { UInt8($0) }
			let data = Data(hashedBytes)

			return data
		}

		/// The status of the verification after upload.
		var status: VerificationStatus
		/// The image that was uploaded.
		var image: Image
		/// The time the record was last updated.
		var lastUpdated: Date
	}

	func getResponse(on db: Database) async throws -> Response {
		guard let imageModel = try await self.$image.get(on: db) else {
			throw Abort(.notFound, reason: "No image attached to the COVID Test data.")
		}

		return .init(
			status: self.status,
			image: imageModel.image,
			lastUpdated: self.lastModified
		)
	}
}
