import Fluent

extension ImageModel {
	struct Create: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(ImageModel.schema)
				.id()
				.field("photo_data", .data, .required)
				.field("mime_type", .string, .required)
				.create()
		}

		func revert(on database: Database) async throws {
			try await database.schema(ImageModel.schema)
				.delete()
		}
	}
}

