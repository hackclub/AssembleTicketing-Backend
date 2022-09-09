import Foundation

extension Date {
	/// The date in ISO-8601 format.
	var iso8601: String {
		let formatter = ISO8601DateFormatter()

		return formatter.string(from: self)
	}
}
