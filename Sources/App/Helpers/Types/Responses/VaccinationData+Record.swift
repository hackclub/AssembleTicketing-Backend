import Foundation
import Vapor
import FluentKit

extension VaccinationData {
	func getRecord(on database: Database) async throws -> VaccinationData.Response.RecordType {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let image = try await self.$image.get(on: database) {
			return .image(image: image)
		}
		throw Abort(.conflict, reason: "No verified or image vaccination available.")
	}
}
