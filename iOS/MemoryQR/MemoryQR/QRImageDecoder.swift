import CoreImage
import UIKit

enum QRImageDecoder {
    enum DecodeError: Error, Equatable {
        case unreadableImage
        case noQRCodeFound
    }

    static func decode(from image: UIImage) throws -> String {
        guard let ciImage = CIImage(image: image) else {
            throw DecodeError.unreadableImage
        }

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )

        guard let features = detector?.features(in: ciImage) as? [CIQRCodeFeature],
              let message = features.first?.messageString,
              !message.isEmpty else {
            throw DecodeError.noQRCodeFound
        }

        return message
    }
}

