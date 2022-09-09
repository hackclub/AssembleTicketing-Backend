import Foundation
import QRCodeGenerator
import SwiftDraw

/// Helper struct for QR code management.
struct QRCode {
	var message: Data

	/// Errors that can arise with QR code generation.
	enum QRCodeError: Error {
		/// The internal conversion of the QR code to the requested format failed.
		case conversionFailed
	}

	/// Returns a string containing an SVG representation of the QR code.
	/// - Parameters:
	///   - errorCorrection: A QRCodeECC value. Defaults to `.low`. 
	func generateSVGString(errorCorrection: QRCodeECC = .low) throws -> String {
		let qr = try QRCodeGenerator.QRCode.encode(binary: .init(message), ecl: errorCorrection)
		let svgString = qr.toSVGString(border: 2)

		return svgString
	}

	/// Returns a Data object containing a UTF-8 encoded SVG representation of the QR code.
	/// - Parameters:
	///   - errorCorrection: A QRCodeECC value. Defaults to `.low`.
	func generateSVG(errorCorrection: QRCodeECC = .low) throws -> Data {
		let svgString = try generateSVGString(errorCorrection: errorCorrection)
		guard let svgData = svgString.data(using: .utf8) else {
			throw QRCodeError.conversionFailed
		}
		return svgData
	}

	/// Returns a Data object containing a PNG encoded SVG representation of the QR code.
	/// - Parameters:
	///   - errorCorrection: A QRCodeECC value. Defaults to `.low`.
	func generatePNG(errorCorrection: QRCodeECC = .low) throws -> Data {
		let svgData = try generateSVG()

		guard let svg = SVG(data: svgData) else {
			throw QRCodeError.conversionFailed
		}
		return try svg.pngData()
	}
}
