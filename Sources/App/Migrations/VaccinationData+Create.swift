import Fluent

extension VaccinationData {
	struct Create: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.id()
				.field("user_id", .uuid, .foreignKey(User.schema, .key(.id), onDelete: .cascade, onUpdate: .noAction))
				.field("card_photo", .data)
				.field("verified_vaccination", .json)
				.create()
		}

		func revert(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.delete()
		}
	}
}

