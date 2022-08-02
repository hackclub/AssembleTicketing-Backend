import Fluent

/// A protocol for Model that are `StatusEncodable` and get some helper functions out of it.
/// You do have to specify a parent path.
protocol ModelStatusEncodable: StatusEncodable, Model {
	static var parentPath: KeyPath<Self, ParentType> { get set }

	/// Attempts to get the parent object on the given database.
	func getParent(on db: Database) async throws -> ParentType

	/// Attempts to get the status from the parent object if it's available in the database.
	func getStatus(on db: Database) async throws -> StatusType
}

extension ModelStatusEncodable {
	func getParent(on db: Database) -> ParentType {
		return self[keyPath: Self.parentPath]
	}

	func getStatus(on db: Database) -> StatusType {
		let parent = self.getParent(on: db)
		return getStatus(from: parent)
	}
}

