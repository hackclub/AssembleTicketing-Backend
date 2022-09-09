import Vapor
import Fluent

extension User {
	/// Looks up whether a User should now be sent a ticket to the event.
	func shouldSendTicket(on db: Database) async throws -> Bool {
		// If there isn't anything, count it as false.
		let testVerified = try await self.$testData.get(on: db)?.status.isVerified ?? false
		let vaccinationVerified = try await self.$vaccinationData.get(on: db)?.status.isVerified ?? false
		let waiverSubmitted = self.waiverStatus != nil

		return testVerified && vaccinationVerified && waiverSubmitted
	}
}
