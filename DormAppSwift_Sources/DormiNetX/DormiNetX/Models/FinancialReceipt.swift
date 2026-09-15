import Foundation
import SwiftData

/// Immutable receipt facts captured when a payment transaction is recorded.
/// Invoice edits after this point must not rewrite these values.
@Model
final class FinancialReceipt: Identifiable {
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute(.unique) var transactionID: UUID = UUID()
    var paymentID: UUID = UUID()
    var receiptNumber: String = ""
    var userID: Int = 0
    var roomNumber: String = ""
    var billingMonth: String = ""
    var invoiceAmount: Double = 0
    var receivedAmount: Double = 0
    var balanceAfter: Double = 0
    var method: String = ""
    var slipPaths: [String] = []
    var issuedAt: Date = Date()
    var lastUpdated: Date = Date()
    var isDirty: Bool = true

    init(transactionID: UUID, paymentID: UUID, receiptNumber: String, issuedAt: Date = Date()) {
        self.transactionID = transactionID
        self.paymentID = paymentID
        self.receiptNumber = receiptNumber
        self.issuedAt = issuedAt
        self.lastUpdated = issuedAt
    }
}
