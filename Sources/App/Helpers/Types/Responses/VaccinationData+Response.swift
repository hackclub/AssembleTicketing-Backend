import Foundation
import Vapor
import Fluent

extension VaccinationData {
	/// The response to a vaccination verification request.
	struct Response: Content, ResponseHashable {
		/// The status of the verification after upload.
		var status: User.VerificationStatus
		/// The vaccination record that was saved.
		var record: RecordType
		/// The time the record was last updated.
		var lastUpdated: Date

		/// The types of vaccination record.
		enum RecordType: Codable {
			/// A verified vaccination record.
			case verified(record: Minimized.VerifiedVaccinationRecord)
			/// An image vaccination record.
			case image(data: Data, filetype: HTTPMediaType)

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

extension VaccinationData {
	func getResponse(on db: Database) async throws -> VaccinationData.Response {
		let record = try await self.getRecord(on: db)
		return try await .init(status: self.$user.get(on: db).vaccinationStatus, record: record, lastUpdated: lastModified)
	}
}
