import re

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Services/AppDate.swift", "r") as f:
    content = f.read()

# Replace formatter to use current locale if it's th_TH originally but respect the app language
new_formatter = """    private static func formatter(_ format: String, locale: String = "en_US_POSIX", buddhist: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        let isThai = Locale.autoupdatingCurrent.language.languageCode?.identifier == "th"
        if locale == "th_TH" {
            formatter.locale = Locale.autoupdatingCurrent
            formatter.calendar = isThai ? Calendar(identifier: .buddhist) : gregorianCalendar
            // Adjust format for English (e.g., remove "เวลา" and "น.")
            var adjustedFormat = format
            if !isThai {
                adjustedFormat = adjustedFormat.replacingOccurrences(of: " เวลา ", with: " ")
                adjustedFormat = adjustedFormat.replacingOccurrences(of: " น.", with: "")
            }
            formatter.dateFormat = adjustedFormat
        } else {
            formatter.locale = Locale(identifier: locale)
            formatter.calendar = buddhist ? Calendar(identifier: .buddhist) : gregorianCalendar
            formatter.dateFormat = format
        }
        formatter.timeZone = timeZone
        formatter.isLenient = false
        return formatter
    }"""

# Replace the formatter function
content = re.sub(r'    private static func formatter\(_ format: String.*?return formatter\n    \}', new_formatter, content, flags=re.DOTALL)

with open("DormAppSwift_Sources/DormiNetX/DormiNetX/Services/AppDate.swift", "w") as f:
    f.write(content)

print("AppDate fixed")
