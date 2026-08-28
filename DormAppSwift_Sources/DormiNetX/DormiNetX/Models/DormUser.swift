import Foundation
import SwiftData

@Model
final class DormUser: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var serverId: Int?
    
    var prefix: String = ""
    var firstName: String = ""
    var lastName: String = ""
    var roomNumber: String = ""
    var status: String = ""
    var nationalID: String = ""
    var phone: String = ""
    var address: String = ""
    var moveInDate: String = ""
    var contractEndDate: String = ""
    var deposit: Double = 0.0
    var bookingStatus: String = ""
    var bookingEndDate: String = ""
    var paymentMethod: String = ""
    var paymentChannel: String = ""
    var installmentMonths: Int = 0
    var installmentAmount: Double = 0.0
    var indefiniteContract: Int = 0
    var bookingSlips: [String] = []
    var additionalAppliances: String = ""
    var additionalApplianceFee: Double = 0.0
    var additionalDetails: String = ""
    
    // Sync Metadata
    var lastUpdated: Date = Date()
    var isDirty: Bool = false
    var isDeletedLocally: Bool = false
    
    init(serverId: Int? = nil, firstName: String = "", lastName: String = "") {
        self.serverId = serverId
        self.firstName = firstName
        self.lastName = lastName
    }
}

func stableLocalUserID(for user: DormUser) -> Int {
    if let serverId = user.serverId, serverId > 0 {
        return serverId
    }

    let value = user.id.uuidString.unicodeScalars.reduce(Int32(17)) { result, scalar in
        result &* 31 &+ Int32(scalar.value)
    }
    return max(1, Int(abs(value)))
}
