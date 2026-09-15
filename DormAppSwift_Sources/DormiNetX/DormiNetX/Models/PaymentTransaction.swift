import Foundation
import SwiftData

/// An append-only record of money received for an issued bill.
///
/// `Payment.paidAmount` remains as a compatibility balance while older app
/// versions exist. New code mirrors every increase into this ledger so a later
/// migration can stop treating one mutable number as the accounting history.
@Model
final class PaymentTransaction: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    var paymentID: UUID = UUID()
    var amount: Double = 0
    var occurredAt: Date = Date()
    var method: String = ""
    var kind: String = "payment"
    var note: String = ""
    var slipPaths: [String] = []
    var source: String = ""
    var lastUpdated: Date = Date()
    var isDirty: Bool = true

    init(paymentID: UUID, amount: Double, occurredAt: Date = Date(), method: String = "", source: String = "") {
        self.paymentID = paymentID
        self.amount = amount
        self.occurredAt = occurredAt
        self.method = method
        self.source = source
        self.lastUpdated = occurredAt
    }
}
