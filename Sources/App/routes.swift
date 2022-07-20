import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req in
        return "It works!"
    }

    app.get("hello") { req -> String in
        return "Hello, world!"
    }

	let authed = app.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])

    try authed.register(collection: VaccinationController())
	try authed.register(collection: UserController())
}
