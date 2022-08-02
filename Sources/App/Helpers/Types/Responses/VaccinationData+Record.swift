import Foundation
import Vapor
import FluentKit

extension VaccinationData {
	func getRecord(on database: Database) async throws -> VaccinationData.Response.RecordType {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageData = self.photoData, let imageType = self.photoType {
			return .image(data: imageData, filetype: imageType)
		}
		throw Abort(.conflict, reason: "No verified or image vaccination available.")
	}
}
