import Foundation

struct AppleWalletEventTicket: AppleWalletPassProperties {
	var formatVersion: Int = 1

	var passTypeIdentifier: String

	var serialNumber: String

	var teamIdentifier: String

	var webServiceURL: URL

	var authenticationToken: String

	var relevantDate: Date?

	var foregroundColor: RGBColor?

	var backgroundColor: RGBColor?

	var labelColor: RGBColor?

	var locations: [Location]?

	var barcodes: [Barcode]?

	var logoText: String

	var organizationName: String

	var description: String

	var eventTicket: EventTicket

	struct EventTicket: Codable {
		var primaryFields: [AppleWalletPassField]?
		var secondaryFields: [AppleWalletPassField]?
		var auxiliaryFields: [AppleWalletPassField]?
		var headerFields: [AppleWalletPassField]?
		var backFields: [AppleWalletPassField]?
	}
}

struct AppleWalletPassField: Codable {
	/// The key for the field.
	var key: String
	/// The value of the field.
	var value: String
	/// The label for the field.
	var label: String?
	/// The message to show the user when the pass is updated.
	var changeMessage: String?
	/// The data detectors that are applies to the field's value. Only applied to back fields.
	var dataDetectorTypes: [DataDetectors]?
	/// The text alignment of the field.
	var textAlignment: TextAlignment?
	// MARK: Date Style
	/// The style of date to display.
	var dateStyle: DateTimeStyle?
	/// Whether to ignore timezones or not.
	var ignoresTimeZone: Bool?
	/// Whether to display the value as a relative date.
	var isRelative: Bool?
	/// The style of time to display.
	var timeStyle: DateTimeStyle?
	// MARK: Number Style
	/// ISO 4217 currency code for the field's value.
	var currencyCode: String?
	/// The style of the number.
	var numberStyle: NumberStyle?

	enum DataDetectors: String, Codable {
		case phoneNumber = "PKDataDetectorTypePhoneNumber"
		case link = "PKDataDetectorTypeLink"
		case address = "PKDataDetectorTypeAddress"
		case calendarEvent = "PKDataDetectorTypeCalendarEvent"
	}

	enum TextAlignment: String, Codable {
		case left = "PKTextAlignmentLeft"
		case center = "PKTextAlignmentCenter"
		case right = "PKTextAlignmentRight"
		case natural = "PKTextAlignmentNatural"
	}

	enum DateTimeStyle: String, Codable {
		case none =  "PKDateStyleNone"
		case short =  "PKDateStyleShort"
		case medium =  "PKDateStyleMedium"
		case long =  "PKDateStyleLong"
		case full =  "PKDateStyleFull"
	}

	enum NumberStyle: String, Codable {
		case decimal = "PKNumberStyleDecimal"
		case percent = "PKNumberStylePercent"
		case scientific = "PKNumberStyleScientific"
		case spellOut = "PKNumberStyleSpellOut"
	}
}

/// A protocol describing all the shared elements of an Apple Wallet pass.
protocol AppleWalletPassProperties: Codable {
    /// The Pass format version. Should be 1.
	var formatVersion: Int { get set }
	/// The reverse-DNS pass identifier.
	var passTypeIdentifier: String { get set }
	/// A serial number for the Pass.
	var serialNumber: String { get set }
	/// The Apple Developer Team ID of the issuing account.
	var teamIdentifier: String { get set }
	/// The URL to the web service for the pass (as described in the pass docs).
	var webServiceURL: URL { get set }
    /// The authentication token for the web service.
	var authenticationToken: String { get set }
    /// The relevant date for the event.
	var relevantDate: Date? { get set }
    /// The foreground color for the pass (for text and whatnot).
	var foregroundColor: RGBColor? { get set }
    /// The background color for the pass.
	var backgroundColor: RGBColor? { get set }
    /// The color for the labels (the small text).
	var labelColor: RGBColor? { get set }
    /// The relevant locations for the pass.
	var locations: [Location]? { get set }
	/// The barcodes for the pass.
	var barcodes: [Barcode]? { get set }
	/// The text that goes next to the logo.
	var logoText: String { get set }
	/// The name of the issuing organization.
	var organizationName: String { get set }
	/// A short description of the pass.
	var description: String { get set }
}

/// A struct containing an RGB color.
struct RGBColor {
    /// 0-1, the red value for the color.
    var red: Double
    /// 0-1, the blue value for the color.
    var blue: Double
    /// 0-1, the green value for the color.
    var green: Double
}

extension RGBColor: LosslessStringConvertible, Codable {
    init?(_ description: String) {
        var description = description

        guard description.removeFirst(3) == "rgb" else {
            return nil
        }

        description = description.trimmingCharacters(in: .init(charactersIn: "()"))

        let components = description.split(separator: ",")
        let trimmedComponents = components.map({ $0.trimmingCharacters(in: .whitespaces) })

        guard
            let redComponent = Int(trimmedComponents[0]),
            let blueComponent = Int(trimmedComponents[1]),
            let greenComponent = Int(trimmedComponents[2])
        else {
            return nil
        }

        self.red = Double(redComponent) / 255
        self.blue = Double(blueComponent) / 255
        self.green = Double(greenComponent) / 255
    }

    var description: String {
        let red = Int(self.red * 255)
        let blue = Int(self.blue * 255)
        let green = Int(self.green * 255)

        return "rgb(\(red), \(green), \(blue))"
    }

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		guard let result = RGBColor(try container.decode(String.self)) else {
			throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not valid RGB values."))
		}

		self = result
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()

		try container.encode(self.description)
	}
}

/// A struct representing a geographical location.
struct Location: Codable {
    /// The longitude of the location.
    var longitude: Double
    /// The latitude of the location.
    var latitude: Double
	/// The altitude, in meters, of the location.
	var altitude: Double?
	/// Text displayed on the lock screen when the pass is currently relevant. For example, a description of the nearby location such as “Store nearby on 1st and Main.”
	var relevantText: String?
}

/// A struct representing a barcode object.
struct Barcode: Codable {
	/// The message to encode.
	var message: String
	/// The format in which to encode it.
	var format: BarcodeFormat
	/// The string encoding to use (IANA format).
	var messageEncoding: String = "iso-8859-1"

	/// Every barcode format supported by Apple Wallet.
	enum BarcodeFormat: String, Codable {
		/// A QR code.
		case qr = "PKBarcodeFormatQR"
		/// A PDF417 code.
		case pdf417 = "PKBarcodeFormatPDF417"
		/// An Aztec code.
		case aztec = "PKBarcodeFormatAztec"
		/// A Code 128 format barcode. **Note: does not work on Apple Watch.**
		case code128 = "PKBarcodeFormatCode128"
	}
}
