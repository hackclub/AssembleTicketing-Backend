import Foundation
import ModelsR4

extension SmartHealthCard.Payload {
	/// A Verifiable Credential that conforms to all of our supported types.
	public struct VerifiableCredential: Codable {
		/// The types of the credential.
		public var type: [CredentialType]
		/// The subject of the credential.
		public var credentialSubject: CredentialSubject
		/// The `rid` of the credential for revocation (if any).
		public var rid: String?
	}
}

extension SmartHealthCard.Payload.VerifiableCredential {
	public struct CredentialSubject: Codable {
		/// The FHIR bundle of the Verifiable Credential, if any.
		public var fhirBundle: ModelsR4.Bundle

		/// The FHIR version of the Verifiable Credential.
		public var fhirVersion: String
	}
}
