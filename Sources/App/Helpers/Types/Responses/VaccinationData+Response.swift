import Foundation
import Vapor
import Fluent

extension VaccinationData {
	/// The response to a vaccination verification request.
	struct Response: Content {
		/// The status of the verification after upload.
		var status: User.VaccinationVerificationStatus
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
		}
	}
}

extension VaccinationData {
	func getResponse(on db: Database) async throws -> VaccinationData.Response {
		guard let record = self.record else {
			throw Abort(.notFound, reason: "No data in vaccination record.")
		}
		return try await .init(status: self.$user.get(on: db).vaccinationStatus, record: record, lastUpdated: lastModified)
	}
}
