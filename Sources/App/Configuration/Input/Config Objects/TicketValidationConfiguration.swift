import Foundation
import Vapor

/// An object for storing Hack Club Ticketing-specific configuration information.
struct TicketValidationConfiguration: EnvironmentConfiguration {
	/// The (ID-server-provided) organization ID to use as the organization for this event.
	var organizationID: UUID
	/// The URL of the client (used for CORS).
	var clientURL: URL
	/// The URL of the ID server (used for token audience validation).
	var idAPIURL: URL

	init() throws {
		self.organizationID = try Environment.convert("ORGANIZATION_ID") { value in
			UUID(uuidString: value)
		}
		self.clientURL = try Environment.convert("CLIENT_URL") { value in
			URL(string: value)
		}
		self.idAPIURL = try Environment.convert("ID_API_URL") { value in
			URL(string: value)
		}
	}
}

struct TicketValidationConfigurationKey: StorageKey {
	typealias Value = TicketValidationConfiguration
}

extension Application {
	var ticketConfig: TicketValidationConfiguration {
		get {
			guard let value = self.storage[TicketValidationConfigurationKey.self] else {
				fatalError("App wasn't configured.")
			}
			return value
		}

		set {
			self.storage[TicketValidationConfigurationKey.self] = newValue
		}
	}
}

extension Request {
	var ticketConfig: TicketValidationConfiguration {
		self.application.ticketConfig
	}
}
