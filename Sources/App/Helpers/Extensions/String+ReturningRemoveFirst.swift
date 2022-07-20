import Foundation

extension String {
	/// Removes the specified number of elements from the beginning of the collection and returns it.
	///
	/// - Parameters
	///   - k: The number of elements to remove from the collection. k must be greater than or equal to zero and must not exceed the number of elements in the collection.
	///
	/// ```var bugs = ["Aphid", "Bumblebee", "Cicada", "Damselfly", "Earwig"]
	/// bugs.removeFirst(3)
	/// print(bugs)
	/// // Prints "["Damselfly", "Earwig"]"
	/// ```
	/// Calling this method may invalidate any existing indices for use with this collection.
	/// Complexity: O(n), where n is the length of the collection.
	mutating public func removeFirst(_ k: Int) -> Substring {
		let prefix = self.prefix(k)
		let _: Void = self.removeFirst(k)

		return prefix
	}
}
