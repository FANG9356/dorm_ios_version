import Foundation
import SwiftData

@Model
final class Room: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serverId: Int?
    
    var roomNumber: String = ""
    var roomType: String = ""
    
    // Sync Metadata
    var lastUpdated: Date = Date()
    var isDirty: Bool = false
    var isDeletedLocally: Bool = false
    
    init(serverId: Int? = nil, roomNumber: String = "", roomType: String = "") {
        self.serverId = serverId
        self.roomNumber = roomNumber
        self.roomType = roomType
    }
}
