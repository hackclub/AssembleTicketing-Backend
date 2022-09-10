import Fluent

extension VaccinationData {
	struct Create: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.id()
				.field(.userID, .uuid, .required, .references(User.schema, .id))
				.field(.imageID, .uuid, .references(ImageModel.schema, .id))
				.field(.status, .string, .required)
				.field(.verifiedVaccination, .json)
				.field(.modifiedDate, .datetime, .required)
				.create()
		}

		func revert(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.delete()
		}
	}
}

