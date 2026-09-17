import Foundation
import SwiftData

@Model
final class Maintenance: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serverId: Int?
    
    var roomNumber: String = ""
    var issue: String = ""
    var status: String = ""
    var cost: Double = 0.0
    var reportedAt: String = ""
    var resolvedAt: String = ""
    var paymentMethod: String = ""
    var slipPath: String = ""
    var issueImage: String = ""
    var quoteApprovedAt: String = ""
    
    // Sync Metadata
    var lastUpdated: Date = Date()
    var isDirty: Bool = false
    var isDeletedLocally: Bool = false
    
    init(serverId: Int? = nil, roomNumber: String = "", issue: String = "") {
        self.serverId = serverId
        self.roomNumber = roomNumber
        self.issue = issue
    }
}
