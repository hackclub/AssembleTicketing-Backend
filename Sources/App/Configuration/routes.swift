import Fluent
import Vapor

func routes(_ app: Application) throws {
	let authed = app.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])

    try authed.register(collection: VaccinationController())
	try authed.register(collection: UserController())
}
