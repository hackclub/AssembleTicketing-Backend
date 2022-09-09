import Foundation
import Vapor

/// All the configuration necessary for SMART Health Card verification in one place.
struct SMARTHealthCardConfiguration: EnvironmentConfiguration {
	/// The valid Issuers for health card validation.
	var issuers: Issuers
	/// The list of nicknames for automatic validation.
	var nicknames: Nicknames

	/// Set up the configuration object by passing the required values.
	init(issuers: Issuers, nicknames: Nicknames) {
		self.issuers = issuers
		self.nicknames = nicknames
	}

	init() throws {
		guard let issuersURL = URL(string: Environment.get("VCI_ISSUERS_LIST_PATH") ?? "") ?? Bundle.module.url(forResource: "vci-issuers", withExtension: "json") else {
			throw ConfigurationErrors.invalidEnvVar(envVar: "VCI_ISSUERS_LIST_PATH")
		}
		guard let nicknamesURL = URL(string: Environment.get("NICKNAMES_LIST_PATH") ?? "") ?? Bundle.module.url(forResource: "nicknames", withExtension: "json") else {
			throw ConfigurationErrors.invalidEnvVar(envVar: "NICKNAMES_LIST_PATH")
		}

		self.issuers = try Issuers(from: issuersURL)
		self.nicknames = try Nicknames(from: nicknamesURL)
	}
}

struct SMARTHealthCardConfigurationKey: StorageKey {
	typealias Value = SMARTHealthCardConfiguration
}

extension Application {
	var healthCardConfig: SMARTHealthCardConfiguration {
		get {
			guard let value = self.storage[SMARTHealthCardConfigurationKey.self] else {
				fatalError("App wasn't configured.")
			}
			return value
		}

		set {
			self.storage[SMARTHealthCardConfigurationKey.self] = newValue
		}
	}
}

extension Request {
	var healthCardConfig: SMARTHealthCardConfiguration {
		self.application.healthCardConfig
	}
}
