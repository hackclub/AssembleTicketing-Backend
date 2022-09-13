import Foundation
import Vapor
import FluentKit

extension VaccinationData {
	/// Gets the appropriate record type from the database for the VaccinationData object.
	func getRecord(on db: Database) async throws -> VaccinationData.Response.RecordType {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageModel = try await self.$image.get(on: db) {
			return .image(image: imageModel.image)
		}
		throw Abort(.conflict, reason: "No verified or image vaccination available.")
	}

	convenience init(_ record: VaccinationData.Response.RecordType, on db: Database) async throws {
		self.init()
		try await self.update(with: record, on: db)
	}

	func update(with record: VaccinationData.Response.RecordType, on db: Database) async throws {
		switch record {
			case .image(let image):
				try await self.updateImage(with: image, on: db)
			case .verified(let record):
				self.verifiedVaccination = record
		}
	}

	var record: VaccinationData.Response.RecordType? {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageVaccination = self.image {
			return .image(image: imageVaccination.image)
		}
		return nil
	}
}
