import Foundation

/// Responses with a status.
protocol StatusEncodable: ResponseEncodable {
	/// The type of the parent class containing the status.
	associatedtype ParentType
	/// The type of the status object we want to encode.
	associatedtype StatusType: Status

	static var parentStatusPath: KeyPath<ParentType, StatusType> { get }

	/// Gets the status from a given parent.
	func getStatus(from parent: ParentType) -> StatusType
}

extension StatusEncodable {
	func getStatus(from parent: ParentType) -> StatusType {
		return parent[keyPath: Self.parentStatusPath]
	}
}

/// A protocol for all the various status types that objects can have for responses.
protocol Status: Codable {}

