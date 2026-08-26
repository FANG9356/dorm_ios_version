import Foundation
import UIKit

enum SlipImageManager {
    private static let directoryName = "PaymentSlips"

    static func url(for storedPath: String) -> URL? {
        let trimmedPath = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        if trimmedPath.hasPrefix("file://"),
           let url = URL(string: trimmedPath) {
            return url
        }

        let url = URL(fileURLWithPath: trimmedPath)
        if url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return try? slipsDirectory().appendingPathComponent(trimmedPath)
    }

    static func saveImageData(_ data: Data) throws -> String {
        let directory = try slipsDirectory()
        let fileName = "slip-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)

        if let image = UIImage(data: data),
           let jpegData = image.jpegData(compressionQuality: 0.88) {
            try jpegData.write(to: url, options: .atomic)
        } else {
            try data.write(to: url, options: .atomic)
        }

        return fileName
    }

    private static func slipsDirectory() throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = baseURL.appendingPathComponent(directoryName, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }
}
