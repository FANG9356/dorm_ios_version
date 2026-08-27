import Foundation
import UIKit

enum AppBackgroundKind: String {
    case system
    case image
    case video
}

enum AppBackgroundManager {
    static let kindKey = "customBackgroundKind"
    static let fileNameKey = "customBackgroundFileName"
    static let updateTokenKey = "customBackgroundUpdateToken"

    private static let directoryName = "CustomBackgrounds"
    private static let imageFileName = "dorminet-background.jpg"
    private static let videoFileName = "dorminet-background.mov"

    static func url(for fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return try? backgroundsDirectory().appendingPathComponent(fileName)
    }

    static func saveImageData(_ data: Data) throws -> String {
        let directory = try backgroundsDirectory()
        let url = directory.appendingPathComponent(imageFileName)

        if let image = UIImage(data: data),
           let jpegData = image.jpegData(compressionQuality: 0.9) {
            try jpegData.write(to: url, options: .atomic)
        } else {
            try data.write(to: url, options: .atomic)
        }

        return imageFileName
    }

    static func saveVideoData(_ data: Data) throws -> String {
        let directory = try backgroundsDirectory()
        let url = directory.appendingPathComponent(videoFileName)
        try data.write(to: url, options: .atomic)
        return videoFileName
    }

    static func restoreFileData(_ data: Data, fileName: String) throws -> String {
        let safeName = URL(fileURLWithPath: fileName).lastPathComponent
        guard !safeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CocoaError(.fileWriteInvalidFileName)
        }

        let directory = try backgroundsDirectory()
        let url = directory.appendingPathComponent(safeName)
        try data.write(to: url, options: .atomic)
        return safeName
    }

    static func clearStoredBackgrounds() {
        guard let directory = try? backgroundsDirectory() else { return }
        [imageFileName, videoFileName].forEach { fileName in
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
        }
    }

    private static func backgroundsDirectory() throws -> URL {
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
