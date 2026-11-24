import Foundation
import UIKit

enum SlipImageManager {
    private static let directoryName = "PaymentSlips"

    static func url(for storedPath: String) -> URL? {
        let trimmedPath = storedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else { return nil }

        let fileName: String
        if trimmedPath.hasPrefix("file://"), let parsedURL = URL(string: trimmedPath) {
            fileName = parsedURL.lastPathComponent
        } else {
            fileName = URL(fileURLWithPath: trimmedPath).lastPathComponent
        }
        guard !fileName.isEmpty, fileName != ".", fileName != "..", !fileName.contains("/") else {
            return nil
        }
        guard let directory = try? slipsDirectory() else { return nil }
        let candidate = directory.appendingPathComponent(fileName).standardizedFileURL
        guard candidate.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            return nil
        }
        return candidate
    }

    static func saveImageData(_ data: Data) throws -> String {
        let directory = try slipsDirectory()
        let fileName = "slip-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(fileName)

        if let image = UIImage(data: data),
           let jpegData = image.jpegData(compressionQuality: 0.88) {
            try jpegData.write(to: url, options: [.atomic, .completeFileProtection])
        } else {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
        }

        return fileName
    }

    static func restoreImageData(_ data: Data, fileName: String) throws -> String {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeName.isEmpty, safeName != ".", safeName != "..", !safeName.contains("/") else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        let directory = try slipsDirectory()
        let url = directory.appendingPathComponent(safeName).standardizedFileURL
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return safeName
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
