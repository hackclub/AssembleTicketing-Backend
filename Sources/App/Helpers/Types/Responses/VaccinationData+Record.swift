import Foundation
import Vapor
import FluentKit

extension VaccinationData {
	convenience init(_ record: VaccinationData.Response.RecordType, on db: Database) async throws {
		switch record {
			case .image(let image):
				// Saving/attaching like this is required to get a type-agnostic relationship.
				let model = ImageModel(image: image)
				try await model.save(on: db)

				self.init()
				self.$image.id = try model.requireID()
			case .verified(let verifiedRecord):
				self.init()
				self.verifiedVaccination = verifiedRecord
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
	
	/// Gets the appropriate record type from the database for the VaccinationData object.
	func getRecord() throws -> VaccinationData.Response.RecordType {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageModel = image {
			return .image(image: imageModel.image)
		}
		throw Abort(.conflict, reason: "No verified or image vaccination available.")
	}
}
