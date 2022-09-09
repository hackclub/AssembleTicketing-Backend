import Fluent

extension CovidTestData {
	struct Create: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(CovidTestData.schema)
				.id()
				.field("user_id", .uuid, .required, .references(User.schema, .id))
				.field("image_id", .uuid, .required, .references(ImageModel.schema, .id))
				.field("modified_date", .datetime, .required)
				.create()
		}

		func revert(on database: Database) async throws {
			try await database.schema(CovidTestData.schema)
				.delete()
		}
	}
}

