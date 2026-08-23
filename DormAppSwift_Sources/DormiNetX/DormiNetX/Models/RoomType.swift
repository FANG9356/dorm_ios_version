import Foundation
import SwiftData

@Model
final class RoomType: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serverId: Int?
    var name: String = ""
    var price: Double = 0
    var waterFee: Double = 0
    var electricFee: Double = 0
    var commonFee: Double = 0
    var lateFee: Double = 0
    var lastUpdated: Date = Date()
    var isDirty: Bool = false

    init(name: String = "", price: Double = 0) {
        self.name = name
        self.price = price
    }
}
