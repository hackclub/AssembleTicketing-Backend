import Fluent
import Vapor
import SQLKit

extension VaccinationData {
	struct AddImageParent: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.field("image_id", .uuid, .references(Image.schema, .id))
				.update()
		}

		func revert(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.deleteField("image_id")
				.update()
		}
	}
}
