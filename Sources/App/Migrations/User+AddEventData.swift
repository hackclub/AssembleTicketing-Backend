import Fluent
import Vapor

extension User {
	struct AddEventData: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(User.schema)
				.field("isCheckedIn", .bool, .required, .sql(.default(false)))
				.field("waiverStatus", .string)
				.update()
		}

		func revert(on database: Database) async throws {
			try await database.schema(User.schema)
				.deleteField("isCheckedIn")
				.deleteField("waiverStatus")
				.update()
		}
	}
}
