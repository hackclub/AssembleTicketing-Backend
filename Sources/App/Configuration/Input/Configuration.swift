import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import ConcurrentIteration
import Mailgun
import PassIssuingKit

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.routes.defaultMaxBodySize = "50mb"

	/// Initialize the configuration from the environment.
	try app.ticketConfig = TicketValidationConfiguration()
	try app.healthCardConfig = SMARTHealthCardConfiguration()
	try app.eventConfig = EventConfiguration()
	try app.mailgunConfig = MailgunConfiguration()

	// CORS
	let corsConfiguration = CORSMiddleware.Configuration(
		allowedOrigin: .custom(app.ticketConfig.clientURL.absoluteString),
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

	// Keys
	let walletSignerJWKSURL = app.walletConfig.passSigningKeyDir.appendingPathComponent("ticketSigner.jwks.json")
	let walletJWKS = try String(contentsOf: walletSignerJWKSURL)
	try app.jwt.signers.use(jwksJSON: walletJWKS)

	if let accessJWKs = try? String(contentsOfFile: Environment.get(withPrejudice: "ACCESS_KEY_URL")) {
		try app.jwt.signers.use(jwksJSON: accessJWKs)
	} else {
		// Set a semaphore to be able to run async tasks
		let semaphore = DispatchSemaphore(value: 0)
		Task {
			let jwksResponse = try await app.client.get(
				.init(
					string: app
						.ticketConfig
						.idAPIURL
						.appendingPathComponent(".well-known/jwks.json")
						.absoluteString
				)
			)
			semaphore.signal()

			let jwks = try jwksResponse.content.decode(JWKS.self)
			try app.jwt.signers.use(jwks: jwks)
		}
		semaphore.wait()
	}

	Pass.setWWDRCert(at: app.walletConfig.passSigningKeyDir.appendingPathComponent("wwdr.pem"))

	// MARK: - Mailgun
	app.mailgun.configuration = .init(apiKey: app.mailgunConfig.mailgunAPIKey)
	app.mailgun.defaultDomain = .init(app.mailgunConfig.mailgunDomain, app.mailgunConfig.mailgunRegion)

	// Migrations
	app.migrations.add(User.Create())
	app.migrations.add(VaccinationData.Create())
	app.migrations.add(VaccinationData.AddMIMEType())
	app.migrations.add(VaccinationData.AddDate())
	app.migrations.add(ImageModel.Create())
	app.migrations.add(VaccinationData.AddImageParent())
//	app.migrations.add(VaccinationData.CopyImages())
	app.migrations.add(User.AddCovidTestState())
	app.migrations.add(CovidTestData.Create())
	app.migrations.add(User.AddEventData())
}
