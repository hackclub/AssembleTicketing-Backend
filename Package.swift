// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "AssembleTicketing",
    platforms: [
       .macOS(.v12)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.0.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0"),
		.package(url: "https://github.com/tsolomko/SWCompression.git", from: "4.7.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "4.0.0"),
		.package(url: "https://github.com/tetraoxygen/jwt-kit.git", branch: "add-zip-support"),
		.package(url: "https://github.com/apple/FHIRModels.git", from: "0.4.0"),
		.package(url: "https://github.com/allotropeinc/ConcurrentIteration.git", from: "1.0.0"),
		.package(url: "https://github.com/fwcd/swift-qrcode-generator.git", from: "1.0.0"),
		.package(url: "https://github.com/vapor-community/mailgun.git", from: "5.0.0"),
		.package(url: "https://github.com/tetraoxygen/PassIssuingKit.git", branch: "main"),
		.package(url: "https://github.com/swhitty/SwiftDraw.git", from: "0.13.0"),
		.package(url: "https://github.com/tetraoxygen/VaporOpenAPI.git", branch: "main"),
	],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
				.product(name: "SWCompression", package: "SWCompression"),
				.product(name: "JWTKit", package: "jwt-kit"),
				.product(name: "JWT", package: "jwt"),
				.product(name: "ModelsR4", package: "FHIRModels"),
				.product(name: "ConcurrentIteration", package: "ConcurrentIteration"),
				.product(name: "QRCodeGenerator", package: "swift-qrcode-generator"),
				.product(name: "Mailgun", package: "Mailgun"),
				.product(name: "PassIssuingKit", package: "PassIssuingKit"),
				.product(name: "SwiftDraw", package: "SwiftDraw"),
				.product(name: "VaporOpenAPI", package: "VaporOpenAPI")
            ],
			resources: [
				.copy("Resources/vci-issuers.json"),
				.copy("Resources/nicknames.json"),
				.copy("Resources/walletbadge.png"),
				.copy("Resources/PassAssets/icon.png"),
				.copy("Resources/PassAssets/icon@2x.png"),
				.copy("Resources/PassAssets/logo.png"),
				.copy("Resources/PassAssets/logo@2x.png"),
				.copy("Resources/PassAssets/strip.png"),
				.copy("Resources/PassAssets/strip@2x.png"),
			],
            swiftSettings: [
                // Enable better optimizations when building in Release configuration. Despite the use of
                // the `.unsafeFlags` construct required by SwiftPM, this flag is recommended for Release
                // builds. See <https://github.com/swift-server/guides/blob/main/docs/building.md#building-for-production> for details.
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        .executableTarget(name: "Run", dependencies: [.target(name: "App")]),
        .testTarget(name: "AppTests", dependencies: [
            .target(name: "App"),
            .product(name: "XCTVapor", package: "vapor"),
        ])
    ]
)
