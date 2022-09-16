import Foundation
import Vapor
import Fluent
import Sampleable

extension User {
	func getCheckInResponse(on db: Database) async throws -> CheckInResponse {
		let vaccinationStatus = try await self.$vaccinationData.get(on: db)?.status
		let covidTestStatus = try await self.$testData.get(on: db)?.status

		return .init(
			isCheckedIn: self.isCheckedIn,
			isVaccinated: vaccinationStatus == .verified,
			hasTestedNegative: covidTestStatus == .verified,
			waiverStatus: self.waiverStatus,
			name: self.name
		)
	}

	/// Just the data the at-the-door person needs to know at a glance.
	struct CheckInResponse: Content, Sampleable {
		static var sample: CheckInResponse {
            return .init(
                isCheckedIn: true,
                isVaccinated: true,
                hasTestedNegative: true,
                name: "Charlie Welsh"
            )
		}

		var isCheckedIn: Bool
		var isVaccinated: Bool
		var hasTestedNegative: Bool
		var waiverStatus: User.WaiverStatus?
		var name: String
	}

	static func find(ticketToken: TicketToken, on db: Database) async throws -> User {
		guard let user = try await User.find(UUID(uuidString: ticketToken.subject.value), on: db) else {
			throw Abort(.notFound, reason: "No user with that ID exists.")
		}

		return user
	}
}

