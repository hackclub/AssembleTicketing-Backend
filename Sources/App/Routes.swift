import Fluent
import Vapor

func routes(_ app: Application) throws {
	let authed = app.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])

	try authed.register(collection: UserController())
	// Not authed because it needs to handle cookie auth, and will handle its own auth.
	try app.register(collection: VaccinationController())
	try app.register(collection: TestController())
	try app.register(collection: TicketController())
}
