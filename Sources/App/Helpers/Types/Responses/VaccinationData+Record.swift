import Foundation
import Vapor

extension VaccinationData {
	convenience init(_ record: VaccinationData.Response.RecordType) {
		switch record {
			case .image(let imageData, let fileType):
				self.init(photoData: imageData, photoType: fileType)
			case .verified(let verifiedRecord):
				self.init(verifiedVaccination: verifiedRecord)
		}
	}

	var record: VaccinationData.Response.RecordType? {
		if let verifiedVaccination = self.verifiedVaccination {
			return .verified(record: verifiedVaccination)
		} else if let imageVaccination = self.photoData, let imageType = self.photoType {
			return .image(data: imageVaccination, filetype: imageType)
		}
		return nil
	}
}
