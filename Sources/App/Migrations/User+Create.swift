import Fluent

extension User {
	struct Create: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(User.schema)
				.id()
				.field(.name, .string, .required)
				.field(.email, .string, .required)
				.unique(on: .email)
				.field(.checkInStatus, .bool, .required)
				.field(.waiverStatus, .json)
				.create()
		}

		func revert(on database: Database) async throws {
			try await database.schema(User.schema)
				.delete()
		}
	}
}

