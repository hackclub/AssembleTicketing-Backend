import Vapor
import Fluent

extension CovidTestData {
	struct Response: Content {
		/// The status of the verification after upload.
		var status: User.VerificationStatus
		/// The image that was uploaded.
		var image: Image
		/// The time the record was last updated.
		var lastUpdated: Date
		/// The code to check for in the image.
		var code: String
	}
}
