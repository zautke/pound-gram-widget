import Foundation

public enum MassUnit: String, Sendable, CaseIterable {
    case pounds
    case grams
}

public enum MassConverter {
    public static let gramsPerPound: Double = 453.59237

    public static func gramsFromPounds(_ lb: Double) -> Double {
        max(0, lb) * gramsPerPound
    }

    public static func poundsFromGrams(_ g: Double) -> Double {
        max(0, g) / gramsPerPound
    }

    public static func convert(_ value: Double, from: MassUnit, to: MassUnit) -> Double {
        guard from != to else { return value }
        switch (from, to) {
        case (.pounds, .grams): return gramsFromPounds(value)
        case (.grams, .pounds): return poundsFromGrams(value)
        default: return value
        }
    }

    public static func parse(_ raw: String, locale: Locale = .current) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let allowed = CharacterSet(charactersIn: "0123456789.,-+ ")
        let stripped = String(trimmed.unicodeScalars.filter { allowed.contains($0) })
            .trimmingCharacters(in: .whitespaces)
        guard !stripped.isEmpty else { return nil }

        if let v = try? Double(stripped, format: .number.locale(locale)) {
            return finite(v)
        }
        let fallback = Locale(identifier: "en_US_POSIX")
        if let v = try? Double(
            stripped.replacingOccurrences(of: ",", with: ""),
            format: .number.locale(fallback)
        ) {
            return finite(v)
        }
        return nil
    }

    public static func formatPounds(_ lb: Double) -> String {
        guard let v = finite(lb) else { return "" }
        return "\(trim(v))#"
    }

    public static func formatGrams(_ g: Double) -> String {
        guard let v = finite(g) else { return "" }
        return "\(trim(v))g"
    }

    public static func spokenString(_ value: Double, unit: MassUnit) -> String {
        let unitWord = unit == .pounds ? "pounds" : "grams"
        return "\(displayString(value)) \(unitWord)"
    }

    public static func formatConversion(value: Double, unit: MassUnit) -> String {
        switch unit {
        case .pounds:
            "\(formatPounds(value)) = \(formatGrams(gramsFromPounds(value)))"
        case .grams:
            "\(formatGrams(value)) = \(formatPounds(poundsFromGrams(value)))"
        }
    }

    public static func displayString(_ value: Double, locale: Locale = .current) -> String {
        trim(value, locale: locale)
    }

    private static func trim(_ v: Double, locale: Locale = .current) -> String {
        guard let safe = finite(v) else { return "" }
        let fs: FloatingPointFormatStyle<Double> = .number
            .precision(.fractionLength(0 ... 4))
            .locale(locale)
        return safe.formatted(fs)
    }

    private static func finite(_ v: Double) -> Double? {
        guard v.isFinite, !v.isNaN else { return nil }
        return v
    }
}
