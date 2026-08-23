import SwiftUI

extension View {
    func digitsOnly(_ text: Binding<String>, maxLength: Int) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            let cleaned = String(newValue.filter(\.isNumber).prefix(maxLength))
            if cleaned != newValue {
                text.wrappedValue = cleaned
            }
        }
    }

    func decimalInput(_ text: Binding<String>, maxIntegerDigits: Int = 9, maxFractionDigits: Int = 2) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            let cleaned = Self.cleanDecimal(newValue, maxIntegerDigits: maxIntegerDigits, maxFractionDigits: maxFractionDigits)
            if cleaned != newValue {
                text.wrappedValue = cleaned
            }
        }
    }

    func limitedText(_ text: Binding<String>, maxLength: Int, trimNewlines: Bool = false) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            var cleaned = trimNewlines ? newValue.replacingOccurrences(of: "\n", with: " ") : newValue
            cleaned = String(cleaned.prefix(maxLength))
            if cleaned != newValue {
                text.wrappedValue = cleaned
            }
        }
    }

    func normalizedEmail(_ text: Binding<String>) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            let allowed = newValue
                .lowercased()
                .filter { !$0.isWhitespace && !$0.isNewline }
            let cleaned = String(allowed.prefix(254))
            if cleaned != newValue {
                text.wrappedValue = cleaned
            }
        }
    }

    func dateKeyInput(_ text: Binding<String>, maxLength: Int = 10) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            let cleaned = String(newValue.filter { $0.isNumber || $0 == "-" }.prefix(maxLength))
            if cleaned != newValue {
                text.wrappedValue = cleaned
            }
        }
    }

    private static func cleanDecimal(_ value: String, maxIntegerDigits: Int, maxFractionDigits: Int) -> String {
        var result = ""
        var hasDecimalSeparator = false
        var integerDigits = 0
        var fractionDigits = 0

        for character in value {
            if character.isNumber {
                if hasDecimalSeparator {
                    guard fractionDigits < maxFractionDigits else { continue }
                    fractionDigits += 1
                } else {
                    guard integerDigits < maxIntegerDigits else { continue }
                    integerDigits += 1
                }
                result.append(character)
            } else if character == "." && !hasDecimalSeparator && maxFractionDigits > 0 {
                hasDecimalSeparator = true
                result.append(character)
            }
        }

        return result
    }
}
