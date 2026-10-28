import Foundation
import SwiftData

@Model
final class Payment: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serverId: Int?
    
    var userId: Int = 0
    var roomNumber: String = ""
    var rentFee: Double = 0.0
    var waterFee: Double = 0.0
    var electricFee: Double = 0.0
    var commonFee: Double = 0.0
    var lateFee: Double = 0.0
    var applianceFee: Double = 0.0
    var depositFee: Double = 0.0
    var amount: Double = 0.0
    var month: String = ""
    var paymentDate: String = ""
    var method: String = ""
    var slipPath: String = ""
    var waterMeterPrev: Double = 0.0
    var waterMeterCurr: Double = 0.0
    var electricMeterPrev: Double = 0.0
    var electricMeterCurr: Double = 0.0
    var paymentPlan: String = ""
    var installmentPhase: Int = 0
    var dueDate: String = ""
    var paymentStatus: String = ""
    var slipPathArray: [String]?
    var paidAmount: Double? = 0.0
    
    // Sync Metadata
    var lastUpdated: Date = Date()
    var isDirty: Bool = false
    var isDeletedLocally: Bool = false
    
    init(serverId: Int? = nil, month: String = "", amount: Double = 0.0) {
        self.serverId = serverId
        self.month = month
        self.amount = amount
    }
}
