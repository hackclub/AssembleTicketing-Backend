import Foundation


/// Errors that occur during the configuration step of setup.
enum ConfigurationErrors: Error {
	/// The app wasn't configured.
	case notConfigured(message: String = "The app wasn't configured.")
	/// The port number was invalid.
	case invalidPortNumber(message: String = "The port number was invalid.")
	/// A required environment variable was missing.
	case missingEnvVar(envVar: String, message: String = "A required environment variable was missing.")
	/// A provided environment variable was invalid.
	case invalidEnvVar(envVar: String, message: String = "A provided environment variable was invalid.")
}
