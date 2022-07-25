import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import ConcurrentIteration

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.routes.defaultMaxBodySize = "50mb"

	/// Initialize the ticketing configuration from the environment.
	try app.ticketingConfiguration = TicketingConfiguration(from: app.environment)

	// CORS
	let corsConfiguration = CORSMiddleware.Configuration(
		allowedOrigin: .custom(app.ticketingConfiguration.clientURL.absoluteString),
		allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
		allowedHeaders: [
			.accept,
			.authorization,
			.authenticationInfo,
			.contentType,
			.origin,
			.xRequestedWith,
			.userAgent,
			.accessControlAllowOrigin,
			.accessControlAllowCredentials
		],
		allowCredentials: true
	)
	let cors = CORSMiddleware(configuration: corsConfiguration)
	// cors middleware should come before default error middleware using `at: .beginning`
	app.middleware.use(cors, at: .beginning)

    app.databases.use(.postgres(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "hc_ticketing",
        password: Environment.get("DATABASE_PASSWORD") ?? "hc_ticketing_password",
        database: Environment.get("DATABASE_NAME") ?? "hc_ticketing"
    ), as: .psql)

    // register routes
    try routes(app)

	// TODO: Support JWKs.
	// Keys
	let accessJWKs = try String(contentsOfFile: Environment.get("ACCESS_KEY_URL")!)
	try app.jwt.signers.use(jwksJSON: accessJWKs)

	// Migrations
	app.migrations.add(User.Create())
	app.migrations.add(VaccinationData.Create())
	app.migrations.add(VaccinationData.AddMIMEType())
	app.migrations.add(VaccinationData.AddDate())
}
