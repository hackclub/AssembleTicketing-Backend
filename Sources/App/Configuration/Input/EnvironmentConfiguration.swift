import Foundation
import Vapor

extension Environment {
	/// A throwing version of Environment.get().
	static func get(withPrejudice varName: String) throws -> String {
		guard let result = Environment.get(varName) else {
			throw ConfigurationErrors.missingEnvVar(envVar: varName)
		}

		return result
	}

	/// Gets with prejudice and attempts to convert a given environment variable to a given type.
	/// - Parameters:
	///   - key: The key of the environment variable to fetch.
	///   - converter: A function that will convert from the environment variable string to an optional generic value. If conversion fails, return nil.
	/// - Throws: `ConfigurationErrors.missingEnvVar` if the value can't be found, `ConfigurationErrors.invalidEnvVar` if it can't be converted.
	static func convert<T>(_ key: String, using converter: (_ value: String) -> T?) throws -> T {
		let value = try Environment.get(withPrejudice: key)
		guard let converted = converter(value) else {
			throw ConfigurationErrors.invalidEnvVar(envVar: key)
		}

		return converted
	}

	/// Gets and attempts to convert a given environment variable to a given (optional) type.
	/// - Parameters:
	///   - key: The key of the environment variable to fetch.
	///   - converter: A function that will convert from the environment variable string to an optional generic value. If conversion fails, return nil.
	/// - Throws: `ConfigurationErrors.invalidEnvVar` if the value can be found, but can't be converted.
	static func convert<T>(optional key: String, using converter: (_ value: String) -> T?) throws -> T? {
		guard let value = Environment.get(key) else {
			return nil
		}
		guard let converted = converter(value) else {
			throw ConfigurationErrors.invalidEnvVar(envVar: key)
		}

		return converted
	}
}

/// A protocol for configuration objects that can initialize from the environment.
protocol EnvironmentConfiguration: Codable {
	/// Initialize the configuration object from the environment automatically.
	init() throws
}
