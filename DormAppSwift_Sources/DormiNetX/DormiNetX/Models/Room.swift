import Foundation
import SwiftData

@Model
final class Room: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serverId: Int?

    // Local account scope. This must be set from the authenticated admin ID.
    // Optional keeps existing SwiftData stores migratable; legacy records are
    // assigned by LocalAccountScope during the first authenticated session.
    var ownerAccountID: Int?

    var roomNumber: String = ""
    var roomType: String = ""

    // Sync Metadata
    var lastUpdated: Date = Date()
    var isDirty: Bool = false
    var isDeletedLocally: Bool = false

    init(serverId: Int? = nil, roomNumber: String = "", roomType: String = "", ownerAccountID: Int? = nil) {
        self.serverId = serverId
        self.roomNumber = roomNumber
        self.roomType = roomType
        self.ownerAccountID = ownerAccountID
    }
}
