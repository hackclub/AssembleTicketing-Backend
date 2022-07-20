import Foundation
import Vapor

extension HTTPMediaType: LosslessStringConvertible, Codable {
	public init?(_ description: String) {
		let slashSplit = description.split(separator: "/")
		guard let type = slashSplit.first, slashSplit.count >= 2 else {
			return nil
		}
		var semicolonSplit = slashSplit[1].split(separator: ";")

		let subType = semicolonSplit.removeFirst()
		let parameterStrings = semicolonSplit.map({ String($0) })

		let parameterTuples = try? parameterStrings.map { string -> (String, String) in
			print(string)
			let substrings = string.split(separator: "=")
			guard substrings.count == 2 else {
				throw Abort(.notFound)
			}
			return (String(substrings[0]), String(substrings[1]))
		}

		guard let parameterTuples = parameterTuples else {
			return nil
		}

		let parameters = Dictionary(uniqueKeysWithValues: parameterTuples)

		self.init(type: String(type), subType: String(subType), parameters: parameters)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()

		try container.encode(self.serialize())
	}

	private static func fromString(_ description: String) -> HTTPMediaType? {
		return Self.init(description)
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		let string = try container.decode(String.self)

		guard let mime = Self.fromString(string) else {
			throw DecodingError.typeMismatch(Self.self, .init(codingPath: container.codingPath, debugDescription: "String wasn't a valid MIME type."))
		}

		self = mime
	}
}
