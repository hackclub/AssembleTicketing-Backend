import Foundation

public protocol JSONURLHandler: Codable {
	associatedtype Value: Codable

	/// The encoded value.
	var value: Value { get set }

	/// The URL for reencoding.
	var url: URL { get }

	/// Initialize the handler from the constituent elements.
	init(value: Value, url: URL)
}

extension JSONURLHandler {
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		let url = try container.decode(URL.self)
		try self.init(from: url)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()

		try container.encode(url)
	}

	/// Take a URL pointing to a JSON file containing data encoded as the associated type and attempt to decode it.
	init(from url: URL) throws {
		let decoder = JSONDecoder()
		let data = try Data(contentsOf: url)
		print(String(data: data, encoding: .utf8))
		let value = try decoder.decode(Value.self, from: data)
		self.init(value: value, url: url)
	}
}

/// A struct containing the authorized Issuers for validation.
struct Nicknames: JSONURLHandler {
	/// A dictionary of all accepted SMART Health Card issuers, with the `iss` URL as the key.
	public var value: [String: [String]]

	public var url: URL
}

/// A struct containing the authorized Issuers for validation.
struct Issuers: JSONURLHandler {
	/// A dictionary of all accepted SMART Health Card issuers, with the `iss` URL as the key.
	var value: [URL: VCIIssuer]

	var url: URL
}

// Do this in an extension so we keep the default memberwise intitializer
extension Issuers {
	init(from url: URL) throws {
		let decoder = JSONDecoder()
		let data = try Data(contentsOf: url)
		let directory = try decoder.decode(VCIDirectory.self, from: data)
		let dictionary = directory.toDictionary()
		self.init(value: dictionary, url: url)
	}
}

extension URL: LosslessStringConvertible {
	public init?(_ description: String) {
		self.init(string: description)
	}
}
