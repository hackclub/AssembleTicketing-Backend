import Foundation
import Vapor

/// An object for storing Hack Club Ticketing-specific configuration information.
struct TicketingConfiguration {
	/// The valid Issuers.
	var issuers: Issuers
	/// The list of nicknames for automatic validation.
	var nicknames: Nicknames
	/// The organization ID to use as the organization for this event.
	var organizationID: UUID
	/// The URL of the client (used for CORS).
	var clientURL: URL
	/// The URL of the ID server (used for token audience validation).
	var idAPIURL: URL

	init(from environment: Environment) throws {
		guard let issuersURL = URL(string: Environment.get("VCI_ISSUERS_LIST_PATH") ?? "") ?? Bundle.module.url(forResource: "vci-issuers", withExtension: "json") else {
			throw ConfigurationErrors.invalidEnvVar(envVar: "VCI_ISSUERS_LIST_PATH")
		}
		guard let nicknamesURL = URL(string: Environment.get("NICKNAMES_LIST_PATH") ?? "") ?? Bundle.module.url(forResource: "nicknames", withExtension: "json") else {
			throw ConfigurationErrors.invalidEnvVar(envVar: "NICKNAMES_LIST_PATH")
		}

		self.issuers = try Issuers(from: issuersURL)
		self.nicknames = try Nicknames(from: nicknamesURL)
		self.organizationID = try Environment.convert("ORGANIZATION_ID", using: { value in
			UUID(uuidString: value)
		})
		self.clientURL = try Environment.convert("CLIENT_URL", using: { value in
			URL(string: value)
		})
		self.idAPIURL = try Environment.convert("ID_API_URL", using: { value in
			URL(string: value)
		})
	}
}

struct TicketingConfigurationKey: StorageKey {
	typealias Value = TicketingConfiguration
}

extension Application {
	var ticketingConfiguration: TicketingConfiguration {
		get {
			guard let value = self.storage[TicketingConfigurationKey.self] else {
				fatalError("App wasn't configured.")
			}
			return value
		}

		set {
			self.storage[TicketingConfigurationKey.self] = newValue
		}
	}
}


extension Request {
	var ticketingConfiguration: TicketingConfiguration {
		self.application.ticketingConfiguration
	}
}
