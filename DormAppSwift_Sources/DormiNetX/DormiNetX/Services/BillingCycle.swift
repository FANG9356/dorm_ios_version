import Foundation

struct BillingCycle {
    let monthId: String
    let label: String
    let dueDay: Int
    let isFuture: Bool

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Bangkok")!
        return calendar
    }

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    static func date(_ value: String) -> Date? {
        let key = String(value.prefix(10))
        let formatter = formatter("yyyy-MM-dd")
        guard let date = formatter.date(from: key), formatter.string(from: date) == key else { return nil }
        return date
    }

    static func dueDateKey(month: String, moveInDate: String) -> String {
        guard let first = date("\(month)-01"), let moveIn = date(moveInDate),
              let days = calendar.range(of: .day, in: .month, for: first) else { return "" }
        let day = min(calendar.component(.day, from: moveIn), days.count)
        guard let due = calendar.date(byAdding: .day, value: day - 1, to: first) else { return "" }
        return formatter("yyyy-MM-dd").string(from: due)
    }

    static func generate(moveInDate: String, contractEndDate: String, indefiniteContract: Bool,
                         now: Date = Date()) -> [BillingCycle] {
        guard let moveIn = date(moveInDate) else { return [] }
        let end: Date
        if indefiniteContract || contractEndDate.isEmpty {
            end = calendar.date(byAdding: .month, value: 12, to: max(moveIn, now)) ?? now
        } else {
            guard let contractEnd = date(contractEndDate), contractEnd >= moveIn else { return [] }
            end = contractEnd
        }
        guard var cursor = calendar.dateInterval(of: .month, for: moveIn)?.start,
              let endMonth = calendar.dateInterval(of: .month, for: end)?.start else { return [] }
        let todayMonth = formatter("yyyy-MM").string(from: now)
        var result: [BillingCycle] = []
        while cursor <= endMonth && result.count < 1200 {
            let month = formatter("yyyy-MM").string(from: cursor)
            let due = dueDateKey(month: month, moveInDate: moveInDate)
            result.append(BillingCycle(monthId: month, label: monthLabel(for: cursor),
                                       dueDay: Int(due.suffix(2)) ?? 1, isFuture: month > todayMonth))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return result
    }

    static func monthLabel(for date: Date) -> String {
        let formatter = formatter("MMMM yyyy")
        formatter.locale = Locale(identifier: "th_TH")
        formatter.calendar = Calendar(identifier: .buddhist)
        return formatter.string(from: date)
    }
}
