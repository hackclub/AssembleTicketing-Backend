import Foundation
import Fluent
import ConcurrentIteration

extension VaccinationData {
	struct CopyImages: AsyncMigration {
		func prepare(on database: Database) async throws {
			let vaccinations = try await VaccinationData.query(on: database).all()
			let images = try await vaccinations.concurrentMap { vaccination -> (id: UUID, image: Image)? in
				if let photoData = vaccination.photoData, let photoType = vaccination.photoType {
					return try (vaccination.requireID(), Image(photoData: photoData, photoType: photoType))
				}
				return nil
			}

			for image in images {
				try await image?.image.save(on: database)

				// yes I know this is inefficient but we only run it once
				let vaccination = vaccinations.first { vaccination in
					vaccination.id == image?.id
				}
				vaccination?.$image.id = image?.image.id
			}
		}

		func revert(on database: Database) async throws {
			try await Image.query(on: database).all().delete(on: database)
		}
	}
}

