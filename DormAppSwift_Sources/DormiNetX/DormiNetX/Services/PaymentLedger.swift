import Foundation
import SwiftData

@MainActor
enum PaymentLedger {
    /// Mirrors any portion of `paidAmount` that is not represented in the
    /// append-only ledger yet. Repeating this operation is safe.
    @discardableResult
    static func recordUnrecordedBalance(
        for payment: Payment,
        in context: ModelContext,
        source: String
    ) throws -> PaymentTransaction? {
        let target = PaymentAmounts.sum([payment.paidAmount])
        guard target.isFinite, target >= 0 else {
            throw LedgerError.invalidAmount
        }

        let existing = try transactions(for: payment.id, in: context)
        let recorded = PaymentAmounts.sum(existing.map(\.amount))
        guard recorded <= target else {
            throw LedgerError.cannotReduceRecordedBalance
        }

        let delta = PaymentAmounts.sum([target, -recorded])
        guard delta > 0 else { return nil }

        let occurredAt = date(from: payment.paymentDate) ?? Date()
        let transaction = PaymentTransaction(
            paymentID: payment.id,
            amount: delta,
            occurredAt: occurredAt,
            method: payment.method,
            source: source
        )
        transaction.slipPaths = evidencePaths(for: payment)
        context.insert(transaction)

        let receipt = FinancialReceipt(
            transactionID: transaction.id,
            paymentID: payment.id,
            receiptNumber: receiptNumber(for: transaction.id),
            issuedAt: occurredAt
        )
        receipt.userID = payment.userId
        receipt.roomNumber = payment.roomNumber
        receipt.billingMonth = payment.month
        receipt.invoiceAmount = PaymentAmounts.sum([payment.amount])
        receipt.receivedAmount = delta
        receipt.balanceAfter = max(PaymentAmounts.sum([payment.amount, -target]), 0)
        receipt.method = payment.method
        receipt.slipPaths = transaction.slipPaths
        context.insert(receipt)
        return transaction
    }

    /// Additive migration for stores/snapshots created before the ledger.
    /// Existing transaction rows are respected, so opening a store repeatedly
    /// never duplicates historical money or receipt records.
    @discardableResult
    static func migrateLegacyBalances(in context: ModelContext) throws -> Int {
        let payments = try context.fetch(FetchDescriptor<Payment>())
        var inserted = 0
        for payment in payments where !payment.isDeletedLocally && payment.paidAmount > 0 {
            if try recordUnrecordedBalance(for: payment, in: context, source: "legacy-balance-migration") != nil {
                inserted += 1
            }
        }
        return inserted
    }

    static func recordedTotal(for paymentID: UUID, in context: ModelContext) throws -> Double {
        PaymentAmounts.sum(try transactions(for: paymentID, in: context).map(\.amount))
    }

    /// A bill with recorded money is accounting evidence. It must be adjusted
    /// through a reversal/refund workflow rather than hidden by the legacy
    /// soft-delete flag, otherwise sync would leave orphan ledger rows.
    static func ensureInvoiceCanBeDeleted(_ payment: Payment, in context: ModelContext) throws {
        guard try recordedTotal(for: payment.id, in: context) == 0 else {
            throw LedgerError.cannotDeleteRecordedInvoice
        }
    }

    private static func transactions(for paymentID: UUID, in context: ModelContext) throws -> [PaymentTransaction] {
        try context.fetch(FetchDescriptor<PaymentTransaction>()).filter { $0.paymentID == paymentID }
    }

    private static func evidencePaths(for payment: Payment) -> [String] {
        var paths = payment.slipPathArray.filter { !$0.isEmpty }
        if !payment.slipPath.isEmpty, !paths.contains(payment.slipPath) {
            paths.append(payment.slipPath)
        }
        return paths
    }

    private static func receiptNumber(for transactionID: UUID) -> String {
        "REC-\(transactionID.uuidString.replacingOccurrences(of: "-", with: "").prefix(12).uppercased())"
    }

    private static func date(from value: String) -> Date? {
        AppDate.date(fromStorageDate: value)
    }

    enum LedgerError: LocalizedError {
        case invalidAmount
        case cannotReduceRecordedBalance
        case cannotDeleteRecordedInvoice

        var errorDescription: String? {
            switch self {
            case .invalidAmount:
                return "ยอดรับชำระไม่ถูกต้อง"
            case .cannotReduceRecordedBalance:
                return "มีรายการรับเงินในประวัติแล้ว ไม่สามารถลดยอดสะสมโดยแก้บิลทับได้"
            case .cannotDeleteRecordedInvoice:
                return "บิลนี้มีประวัติรับเงินแล้ว ต้องใช้ขั้นตอนคืนเงินหรือปรับยอดแทนการลบ"
            }
        }
    }
}
