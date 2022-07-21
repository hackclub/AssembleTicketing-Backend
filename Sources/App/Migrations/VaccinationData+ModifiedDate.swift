import Fluent
import Vapor
import SQLKit

extension VaccinationData {
	struct AddDate: AsyncMigration {
		func prepare(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.field("modified_date", .datetime, .required)
				.update()
		}

		func revert(on database: Database) async throws {
			try await database.schema(VaccinationData.schema)
				.deleteField("modified_date")
				.update()
		}
	}
}
