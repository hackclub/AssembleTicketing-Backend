import Fluent
import Vapor

extension User {
	struct AddCovidTestState: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(User.schema)
				.field("testStatus", .string, .required, .sql(.default("noData")))
				.update()
		}

		func revert(on database: Database) async throws {
			try await database.schema(User.schema)
				.deleteField("testStatus")
				.update()
		}
	}
}
