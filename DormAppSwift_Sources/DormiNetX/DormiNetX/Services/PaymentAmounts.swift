import Foundation

enum PaymentAmounts {
    static func sum(_ values: [Double]) -> Double {
        guard values.allSatisfy(\.isFinite) else { return .nan }
        var value = values.reduce(Decimal.zero) {
            $0 + (Decimal(string: String($1), locale: Locale(identifier: "en_US_POSIX")) ?? .nan)
        }
        var result = Decimal.zero
        NSDecimalRound(&result, &value, 2, .plain)
        return NSDecimalNumber(decimal: result).doubleValue
    }

    static func input(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    // Old bills may include an unlabelled deposit or adjustment. Preserve it, never infer its purpose.
    static func unallocated(in payment: Payment) -> Double {
        sum([payment.amount, -payment.rentFee, -payment.waterFee, -payment.electricFee,
             -payment.commonFee, -payment.lateFee, -payment.applianceFee, -payment.depositFee])
    }

    static func validate(total: Double, paid: Double, status: String, previousPaid: Double = 0) throws {
        guard total.isFinite, paid.isFinite, previousPaid.isFinite, total >= 0, paid >= 0 else {
            throw InvalidPayment("ยอดเงินต้องเป็นตัวเลขที่ไม่ติดลบ")
        }
        let total = sum([total])
        let paid = sum([paid])
        let previousPaid = sum([previousPaid])
        guard paid <= total else { throw InvalidPayment("ยอดรับชำระมากกว่ายอดบิล กรุณาตรวจสอบจำนวนเงิน") }
        guard paid >= previousPaid, total >= previousPaid else {
            throw InvalidPayment("บิลนี้มีการรับเงินแล้ว ไม่สามารถลดยอดรับเงินเดิมจากฟอร์มแก้ไขได้")
        }
        switch status {
        case "paid":
            guard paid == total else { throw InvalidPayment("ยอดรับชำระยังไม่ครบยอดบิล") }
        case "partial":
            guard paid > 0, paid < total else { throw InvalidPayment("จ่ายบางส่วนต้องมากกว่า 0 และน้อยกว่ายอดบิล") }
        case "pending":
            guard paid == 0 else { throw InvalidPayment("บิลรอชำระต้องไม่มียอดรับเงิน") }
        default: throw InvalidPayment("สถานะการชำระไม่ถูกต้อง")
        }
    }

    struct InvalidPayment: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
