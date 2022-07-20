import Foundation
import Vapor

extension Minimized {
	/// The minimum we need to know about a SMART Health Card issuer.
	struct Issuer: Content {
		/// The name of the issuer.
		var name: String
		/// The URL of the issuer's SMART Health Card key registry.
		var url: URL
	}
}
