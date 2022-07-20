import Fluent
import Vapor

extension VaccinationData {
	struct AddMIMEType: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.field("card_photo_type", .string, .sql(.default("noData")))
				.update()
		}

		func revert(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.deleteField("image_type")
				.update()
		}
	}
}
