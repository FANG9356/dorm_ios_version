import Foundation

enum AppDate {
    static let timeZone = TimeZone(identifier: "Asia/Bangkok")!

    static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func formatter(_ format: String, locale: String = "en_US_POSIX", buddhist: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: locale)
        formatter.calendar = buddhist ? Calendar(identifier: .buddhist) : gregorianCalendar
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }

    static func normalizedMonthKey(_ value: String) -> String? {
        let components = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 2,
              var year = Int(components[0]),
              let month = Int(components[1]),
              (1...12).contains(month) else { return nil }
        if year > 2400 { year -= 543 }
        guard (1...9999).contains(year) else { return nil }
        let key = String(format: "%04d-%02d", year, month)
        return strictDate("\(key)-01") == nil ? nil : key
    }

    static func normalizedDateKey(_ value: String) -> String? {
        let datePart = String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
        let components = datePart.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 3,
              var year = Int(components[0]),
              let month = Int(components[1]),
              let day = Int(components[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        if year > 2400 { year -= 543 }
        guard (1...9999).contains(year) else { return nil }
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        return strictDate(key) == nil ? nil : key
    }

    static func date(fromStorageDate value: String) -> Date? {
        guard let key = normalizedDateKey(value) else { return nil }
        return strictDate(key)
    }

    static func date(fromStorageMonth value: String) -> Date? {
        guard let key = normalizedMonthKey(value) else { return nil }
        return strictDate("\(key)-01")
    }

    static func dateKey(from date: Date) -> String {
        formatter("yyyy-MM-dd").string(from: date)
    }

    static func monthKey(from date: Date) -> String {
        formatter("yyyy-MM").string(from: date)
    }

    static func thaiDate(_ value: String, fallback: String = "-") -> String {
        guard let date = date(fromStorageDate: value) else {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        return formatter("d MMM yyyy", locale: "th_TH", buddhist: true).string(from: date)
    }

    static func thaiDayMonth(_ value: String, fallback: String = "-") -> String {
        guard let date = date(fromStorageDate: value) else {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }
        return formatter("d MMM", locale: "th_TH", buddhist: true).string(from: date)
    }

    static func thaiMonth(_ value: String, fallback: String? = nil) -> String {
        guard let date = date(fromStorageMonth: value) else {
            return fallback ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return formatter("MMMM yyyy", locale: "th_TH", buddhist: true).string(from: date)
    }

    static func thaiShortMonth(_ value: String, fallback: String? = nil) -> String {
        guard let date = date(fromStorageMonth: value) else {
            return fallback ?? value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return formatter("MMM yy", locale: "th_TH", buddhist: true).string(from: date)
    }

    static func thaiDateTime(_ date: Date) -> String {
        formatter("d MMMM yyyy เวลา HH:mm น.", locale: "th_TH", buddhist: true).string(from: date)
    }

    static func thaiDateTime(from value: String, fallback: String = "-") -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return thaiDateTime(date)
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return thaiDateTime(date)
        }

        let legacyFormatter = DateFormatter()
        legacyFormatter.locale = Locale(identifier: "en_US_POSIX")
        legacyFormatter.timeZone = timeZone
        legacyFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = legacyFormatter.date(from: value) {
            return thaiDateTime(date)
        }

        legacyFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = legacyFormatter.date(from: value) {
            return thaiDateTime(date)
        }

        let customFormatter = Self.formatter("yyyy-MM-dd HH:mm:ss")
        if let date = customFormatter.date(from: value) {
            return thaiDateTime(date)
        }
        let customFormatter2 = Self.formatter("yyyy-MM-dd")
        if let date = customFormatter2.date(from: value) {
            return thaiDateTime(date)
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private static func strictDate(_ key: String) -> Date? {
        let parser = formatter("yyyy-MM-dd")
        guard let date = parser.date(from: key), parser.string(from: date) == key else { return nil }
        return date
    }
}
