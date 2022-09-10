import Foundation
import Vapor
import PassIssuingKit

struct WalletPassConfiguration: EnvironmentConfiguration {
	/// The path to the ticket/pass signing keys.
	var passSigningKeyDir: URL
	/// The Team ID for Wallet passes.
	var teamID: String
	/// The password for the Wallet pass signing key.
	var passSigningKeyPassword: String
	/// The pass type identifier from the Apple Developer site.
	var passTypeIdentifier: String

	// MARK: Colors
	/// The foreground color of the Wallet pass, hex formatted (without the hash).
	var foregroundColor: RGBColor?
	/// The background color of the Wallet pass, hex formatted (without the hash).
	var backgroundColor: RGBColor?
	/// The label color of the Wallet pass, hex formatted (without the hash).
	var labelColor: RGBColor?

	init(passSigningKeyDir: URL, teamID: String, passSigningKeyPassword: String, passTypeIdentifier: String, foregroundColor: RGBColor?, backgroundColor: RGBColor?, labelColor: RGBColor?) {
		self.passSigningKeyDir = passSigningKeyDir
		self.teamID = teamID
		self.passSigningKeyPassword = passSigningKeyPassword
		self.passTypeIdentifier = passTypeIdentifier
		self.foregroundColor = foregroundColor
		self.backgroundColor = backgroundColor
		self.labelColor = labelColor
	}

	init() throws {
		self.passSigningKeyDir = try Environment.convert("KEYS_PATH") { value in
			URL(fileURLWithPath: value)
		}
		self.teamID = try Environment.get(withPrejudice: "TEAM_ID")
		self.passSigningKeyPassword = try Environment.get(withPrejudice: "WALLET_SIGNING_PASSWORD")
		self.passTypeIdentifier = try Environment.get(withPrejudice: "PASS_TYPE_IDENTIFIER")
		self.foregroundColor = try Environment.convert("PASS_FOREGROUND_COLOR") { value in
			.init(hex: value)
		}
		self.backgroundColor = try Environment.convert("PASS_BACKGROUND_COLOR") { value in
			.init(hex: value)
		}
		self.labelColor = try Environment.convert("PASS_LABEL_COLOR") { value in
			.init(hex: value)
		}
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
