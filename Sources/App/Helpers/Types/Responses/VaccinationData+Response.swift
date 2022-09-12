import Foundation
import Vapor
import VaporToOpenAPI
import Fluent

extension VaccinationData: ResponseEncodable {
	func getResponse(on db: Database) async throws -> Response {
		let record = try await self.getRecord(on: db)
		return .init(status: status, record: record, lastUpdated: lastModified)
	}

	/// The response to a vaccination verification request.
	struct Response: Content, ResponseHashable, WithAnyExample {
		static var anyExample: Codable {
			Self.init(
				status: .verified,
				record: .verified(
					record: .init(
						issuer: .init(name: "The Hack Foundation", url: .init(string: "https://hackclub.com")!),
						name: "Charlie Welsh",
						secondShotDate: .init(timeIntervalSince1970: 0)
					)
				),
				lastUpdated: .init(timeIntervalSince1970: 0)
			)
		}

		func sha256() -> Data {
			var hasher = SHA256()

			// Convert the typeString for the record (e.g, "verified" or "image") to a UTF-8 blob of data (this is imperfect, but the tradeoff in correctness in the corner case is worth the speed bonus here)
			let recordData = Data(record.typeString.utf8)
			// Convert the status type name to a UTF-8 blob of data
			let statusData = Data(status.rawValue.utf8)
			// Convert the time to second-based UNIX epoch time and the convert that to data
			var intLastModified = Int(self.lastUpdated.timeIntervalSince1970)
			let lastModifiedData = Data(
				bytes: &intLastModified,
				count: MemoryLayout.size(ofValue: intLastModified)
			)

			hasher.update(data: recordData)
			hasher.update(data: statusData)
			hasher.update(data: lastModifiedData)
			let hashed = hasher.finalize()
			let hashedBytes = hashed.compactMap { UInt8($0) }
			let data = Data(hashedBytes)

			return data
		}

		/// The status of the verification after upload.
		var status: VerificationStatus
		/// The vaccination record that was saved.
		var record: RecordType
		/// The time the record was last updated.
		var lastUpdated: Date

		/// The types of vaccination record.
		enum RecordType: Codable {
			/// A verified vaccination record.
			case verified(record: Minimized.VerifiedVaccinationRecord)
			/// An image vaccination record.
			case image(image: Image)

			/// A string that represents the type.
			var typeString: String {
				switch self {
					case .verified:
						return "verified"
					case .image:
						return "image"
				}
			}
		}
	}
}
