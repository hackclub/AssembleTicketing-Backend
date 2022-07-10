import Foundation

extension Data {
	/// Returns a Base-64-URL encoded string.
	///
	/// Replaces reserved characters as per https://datatracker.ietf.org/doc/html/rfc4648.
	func base64URLEncodedString() -> String {
		base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
			.trimmingCharacters(in: .whitespaces)
	}

	/// Initialize a `Data` object from a base64url encoded string, with the given options.
	init?(base64URLEncoded b64: String, options: Base64DecodingOptions = []) {
		var b64 = b64
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		while b64.count % 4 != 0 {
			b64 = b64.appending("=")
		}
		self.init(base64Encoded: b64, options: options)
	}
}
