import Foundation

/// A protocol for types that the client can hash to get a consistency check for.
protocol ResponseHashable {
	/// Returns a consistent sha256 hash of an object.
	func sha256() -> Data

	/// Returns whether a given hash is equivalent between `self` and a given base64URL encoded hash.
	/// - Parameters:
	///   - stringHash: The client-generated hash string. It's base64URL encoded.
	/// - Returns: Whether a given hash is equivalent to the hash for a current object.
	func isEquivalent(from stringHash: String?) -> Bool
}

extension ResponseHashable {
	func isEquivalent(from stringHash: String?) -> Bool {
		guard let stringHash = stringHash else {
			return false
		}
		let ownHash = self.sha256().base64URLEncodedString()
		return ownHash == stringHash
	}
}
