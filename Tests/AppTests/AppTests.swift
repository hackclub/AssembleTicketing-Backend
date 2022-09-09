@testable import App
import XCTVapor

final class AppTests: XCTestCase {
//    func testHelloWorld() throws {
//        let app = Application(.testing)
//        defer { app.shutdown() }
//        try configure(app)
//
//        try app.test(.GET, "hello", afterResponse: { res in
//            XCTAssertEqual(res.status, .ok)
//            XCTAssertEqual(res.body.string, "Hello, world!")
//        })
//    }

	let qr = QRCode(message: "foo".data(using: .utf8)!)

	func testQRPNG() throws {
		let qrData = try qr.generatePNG()

		let homeDir = FileManager.default.homeDirectoryForCurrentUser

		try qrData.write(to: homeDir.appendingPathComponent("Downloads/test.png"))


	}

	func testQRSVG() throws {
		let qrData = try qr.generateSVG()

		let homeDir = FileManager.default.homeDirectoryForCurrentUser

		try qrData.write(to: homeDir.appendingPathComponent("Downloads/test.svg"))
	}
}
