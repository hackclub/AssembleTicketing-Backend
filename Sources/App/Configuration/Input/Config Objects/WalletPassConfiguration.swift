import Foundation
import Vapor

struct WalletPassConfiguration: EnvironmentConfiguration {
	/// The path to the ticket/pass signing keys.
	var passSigningKeyDir: URL
	/// The Team ID for Wallet passes.
	var teamID: String
	/// The password for the Wallet pass signing key.
	var passSigningKeyPassword: String
	/// The pass type identifier from the Apple Developer site.
	var passTypeIdentifier: String

	init(passSigningKeyDir: URL, teamID: String, passSigningKeyPassword: String, passTypeIdentifier: String) {
		self.passSigningKeyDir = passSigningKeyDir
		self.teamID = teamID
		self.passSigningKeyPassword = passSigningKeyPassword
		self.passTypeIdentifier = passTypeIdentifier
	}

	init() throws {
		self.passSigningKeyDir = try Environment.convert("KEYS_PATH") { value in
			URL(fileURLWithPath: value)
		}
		self.teamID = try Environment.get(withPrejudice: "TEAM_ID")
		self.passSigningKeyPassword = try Environment.get(withPrejudice: "WALLET_SIGNING_PASSWORD")
		self.passTypeIdentifier = try Environment.get(withPrejudice: "PASS_TYPE_IDENTIFIER")
	}
}

struct WalletPassConfigurationKey: StorageKey {
	typealias Value = WalletPassConfiguration
}

extension Application {
	var walletConfig: WalletPassConfiguration {
		get {
			guard let value = self.storage[WalletPassConfigurationKey.self] else {
				fatalError("App wasn't configured.")
			}
			return value
		}

		set {
			self.storage[WalletPassConfigurationKey.self] = newValue
		}
	}
}

extension Request {
	var walletConfig: WalletPassConfiguration {
		self.application.walletConfig
	}
}
