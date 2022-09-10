import Foundation
import Vapor

/// A struct used to decode a Codable format config file.
struct AllConfig: Codable {
	/// The ticket configuration.
	var ticketConfig: TicketValidationConfiguration
	/// The health card configuration.
	var healthCardConfig: SMARTHealthCardConfiguration
	/// The event configuration.
	var eventConfig: EventConfiguration
	/// The Wallet pass configuration.
	var walletConfig: WalletPassConfiguration
	/// The Mailgun configuration.
	var mailgunConfig: MailgunConfiguration

	/// Initialize from the application's environment.
	init() throws {
		self.ticketConfig = try TicketValidationConfiguration()
		self.healthCardConfig = try SMARTHealthCardConfiguration()
		self.eventConfig = try EventConfiguration()
		self.walletConfig = try WalletPassConfiguration()
		self.mailgunConfig = try MailgunConfiguration()
	}
}

extension Application {
	/// Configure the application with an `AllConfig` object.
	func configure(with config: AllConfig) {
		self.ticketConfig = config.ticketConfig
		self.healthCardConfig = config.healthCardConfig
		self.eventConfig = config.eventConfig
		self.walletConfig = config.walletConfig
		self.mailgunConfig = config.mailgunConfig
	}
}
