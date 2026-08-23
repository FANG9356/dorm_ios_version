import Foundation
import SwiftData

@Model
final class LocalSystemLog: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var action: String = ""
    var details: String = ""
    var timestamp: Date = Date()

    init(action: String = "", details: String = "") {
        self.action = action
        self.details = details
    }
}
