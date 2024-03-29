import Foundation

/// An issuer from the VCI directory.
struct VCIIssuer: Codable {
	/// The URL of the issuer.
	var iss: URL
	/// The (separate) canonical URL of the issuer, if there is one.
	var canonical_iss: URL?
	/// The name of the issuer.
	var name: String
	/// The URL of the website of the issuer, if they have one.
	var website: URL?

	var issuer: URL {
		guard let canonical_iss = canonical_iss else {
			return iss
		}
		return canonical_iss
	}
}

/// A list of VCI issuers.
struct VCIDirectory: Codable {
	var participating_issuers: [VCIIssuer]

	/// Convert the directory to a dictionary with the `iss` URLs as the keys. 
	func toDictionary() -> [URL: VCIIssuer] {
		let issuerTuple = participating_issuers.map { issuer in
			// Uses iss, not canonical, so it's actually unique
			return (issuer.iss, issuer)
		}

		return Dictionary(uniqueKeysWithValues: issuerTuple)
	}
}
