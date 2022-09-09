import Fluent

extension FieldKey {
	/// A key for a field containing an object's name.
	static var name: FieldKey = "name"
	/// A key for a field containing an email associated with a User.
	static let email: FieldKey = "email"
	
	/// A key for a field containing a check-in status associated with a User.
	static let checkInStatus: FieldKey = "check_in_status"
	/// A key for a field containing a waiver status associated with a User.
	static let waiverStatus: FieldKey = "waiver_status"

	/// A key for a field containing a generic status object.
	static let status: FieldKey = "status"
	/// A key for a field containing a MIME type.
	static let mimeType: FieldKey = "mime_type"
	/// A key for a field containing generic data.
	static let data: FieldKey = "data"
	/// A key for a field containing a last-modified date.
	static let modifiedDate: FieldKey = "modified_date"

	/// A key for a field containing a minimized verified vaccination.
	static let verifiedVaccination: FieldKey = "verified_vaccination"

	// MARK: Reference Fields
	/// A key for a field containing a reference to a `User`.
	static let userID: FieldKey = "user_id"
	/// A key for a field containing a reference to an `ImageModel`.
	static let imageID: FieldKey = "image_id"
}
