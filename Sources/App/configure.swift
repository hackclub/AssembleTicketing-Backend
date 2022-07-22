import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import ConcurrentIteration

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

	app.routes.defaultMaxBodySize = "10mb"

	// CORS
	let corsConfiguration = CORSMiddleware.Configuration(
		allowedOrigin: .all,
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
        username: Environment.get("DATABASE_USERNAME") ?? "vapor",
        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
        database: Environment.get("DATABASE_NAME") ?? "assemble_ticketing"
    ), as: .psql)

    // register routes
    try routes(app)

	// Keys
	let accessPEM = try String(contentsOfFile: Environment.get("ACCESS_KEY_PATH")!)
	let accessKey = try RSAKey.public(pem: accessPEM)
	let accessSigner: JWTSigner = .rs256(key: accessKey)
	app.jwt.signers.use(accessSigner, kid: "access", isDefault: true)

	// Migrations
	app.migrations.add(User.Create())
	app.migrations.add(VaccinationData.Create())
	app.migrations.add(VaccinationData.AddMIMEType())
	app.migrations.add(VaccinationData.AddDate())

	/// Get issuers.
	guard let issuerListURL = Bundle.module.url(forResource: "vci-issuers", withExtension: "json") else {
		throw Abort(.internalServerError, reason: "Couldn't load VCI issuers list.")
	}

	let decoder = JSONDecoder()
	decoder.dateDecodingStrategy = .secondsSince1970

	let issuerListData = try Data(contentsOf: issuerListURL)

	// Get the isusers.
	let issuerList = try decoder.decode(VCIDirectory.self, from: issuerListData).participating_issuers
	// This explicitly uses `iss` values, not the canonical issuer, since canonical issuers can be the same as another `iss` value. 
	let issuerTuples = issuerList.map({ vciIssuer in
		(vciIssuer.iss, vciIssuer)
	})
	issuers = Dictionary(uniqueKeysWithValues: issuerTuples)
}

/// A dictionary of the issuers, where the key is the issuer URL.
var issuers: [URL: VCIIssuer] = [:]

let decoder = JSONDecoder()
let nicknames = try! decoder.decode([String: [String]].self, from: Data(contentsOf: Bundle.module.url(forResource: "nicknames", withExtension: "json")!))

// TODO: Make this configurable
let assembleOrgID = UUID(uuidString: "8ceeeff2-276d-4e73-93a4-eaa33bd43677")!
let clientURL: URL = URL(string: Environment.get("CLIENT_URL") ?? "https://ticketing.assemble.hackclub.com/")!
let idAPIURL: URL = URL(string: Environment.get("ID_URL") ?? "https://api.id.assemble.hackclub.com/")!
