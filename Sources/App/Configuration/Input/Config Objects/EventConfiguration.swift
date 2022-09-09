import Foundation
import Vapor

/// Configuration information for event metadata.
struct EventConfiguration: EnvironmentConfiguration {
	/// The event name.
	var eventName: String
	/// The name to use for the event's location.
	var eventLocation: String
	/// The name of the organization putting on the event.
	var organizationName: String
	/// The ISO-8601 format date of the event.
	var date: Date

	init(eventName: String, eventLocation: String, organizationName: String, date: Date) {
		self.eventName = eventName
		self.eventLocation = eventLocation
		self.organizationName = organizationName
		self.date = date
	}

	init() throws {
		self.eventName = try Environment.get(withPrejudice: "EVENT_NAME")
		self.eventLocation = try Environment.get(withPrejudice: "EVENT_LOCATION")
		self.organizationName = try Environment.get(withPrejudice: "ORGANIZATION_NAME")
		self.date = try Environment.convert("EVENT_DATE") { value in
			return ISO8601DateFormatter().date(from: value)
		}
	}
}

struct EventConfigurationKey: StorageKey {
	typealias Value = EventConfiguration
}

extension Application {
	var eventConfig: EventConfiguration {
		get {
			guard let value = self.storage[EventConfigurationKey.self] else {
				fatalError("App wasn't configured.")
			}
			return value
		}

		set {
			self.storage[EventConfigurationKey.self] = newValue
		}
	}
}

extension Request {
	var eventConfig: EventConfiguration {
		self.application.eventConfig
	}
}
