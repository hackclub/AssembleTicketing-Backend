import Fluent
import Vapor
import VaporToOpenAPI
import Swiftgger
import VDCodable

func routes(_ app: Application) throws {
	let authed = app.grouped([AccessToken.authenticator(), AccessToken.guardMiddleware()])

	try authed.register(collection: UserController())
	// Not authed because it needs to handle cookie auth, and will handle its own auth.
	try app.register(collection: VaccinationController())
	try app.register(collection: TestController())
	try app.register(collection: TicketController())

	let openAPI = app.routes.openAPI(
		title: "Assemble Ticketing",
		version: "1.0.0",
		description: "The Assemble Ticketing API",
		authorizations: [
			.jwt(description: "foo")
		],
		objects: [
			.init(object: UserController.ObjectType.Response.anyExample),
			.init(object: VaccinationController.ObjectType.Response.anyExample),
			.init(object: TestController.ObjectType.Response.anyExample),
			.init(object: Image.anyExample),
			.init(object: User.CheckInResponse.anyExample)
		]
	)

	print(APIBodyType(type: String.self, example: nil))

	let data = try VDJSONEncoder(dateEncodingStrategy: .iso8601, dataEncodingStrategy: .base64).encodeToJSON(openAPI)
	print(data)
}
