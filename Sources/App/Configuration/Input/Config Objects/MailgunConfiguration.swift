import Foundation
import Vapor
import Mailgun

/// Configuration for the Mailgun API.
struct MailgunConfiguration: EnvironmentConfiguration {
	/// The API key for your Mailgun account.
	var mailgunAPIKey: String
	/// The domain to send ticketing emails from (must be on your Mailgun account).
	var mailgunDomain: String
	/// The region to use for the Mailgun domain.
	var mailgunRegion: MailgunRegion

	init(mailgunAPIKey: String, mailgunDomain: String, mailgunRegion: MailgunRegion) {
		self.mailgunAPIKey = mailgunAPIKey
		self.mailgunDomain = mailgunDomain
		self.mailgunRegion = mailgunRegion
	}

	init() throws {
		self.mailgunAPIKey = try Environment.get(withPrejudice: "MAILGUN_API_KEY")
		self.mailgunDomain = try Environment.get(withPrejudice: "MAILGUN_DOMAIN")
		self.mailgunRegion = try Environment.convert("MAILGUN_REGION") { value in
			MailgunRegion(rawValue: value)
		}
	}
}

extension MailgunRegion: Codable { }

struct MailgunConfigurationKey: StorageKey {
	typealias Value = MailgunConfiguration
}

extension Application {
	var mailgunConfig: MailgunConfiguration {
		get {
			guard let value = self.storage[MailgunConfigurationKey.self] else {
				fatalError("App wasn't configured.")
			}
			return value
		}

		set {
			self.storage[MailgunConfigurationKey.self] = newValue
		}
	}
}

extension Request {
	var mailgunConfig: MailgunConfiguration {
		self.application.mailgunConfig
	}
}
