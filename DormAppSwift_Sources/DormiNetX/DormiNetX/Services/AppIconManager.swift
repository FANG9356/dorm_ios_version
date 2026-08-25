import UIKit

@MainActor
enum AppIconManager {
    static var supportsAlternateIcons: Bool {
        UIApplication.shared.supportsAlternateIcons
    }

    static var currentIconName: String? {
        UIApplication.shared.alternateIconName
    }

    static func setIcon(_ iconName: String?) async -> Result<Void, Error> {
        guard supportsAlternateIcons else {
            return .failure(AppIconError.unsupported)
        }

        if UIApplication.shared.alternateIconName == iconName {
            return .success(())
        }

        return await withCheckedContinuation { continuation in
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error {
                    continuation.resume(returning: .failure(error))
                } else {
                    continuation.resume(returning: .success(()))
                }
            }
        }
    }
}

enum AppIconError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "เครื่องนี้ยังไม่รองรับการเปลี่ยนไอคอนแอพ"
        }
    }
}
