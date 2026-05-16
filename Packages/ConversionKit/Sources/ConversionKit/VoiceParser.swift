import Foundation

public enum VoiceParser {
    public struct Result: Sendable, Equatable {
        public let value: Double
        public let unit: MassUnit
    }

    public enum ParseError: Error, Sendable, Equatable {
        case noNumber
        case noUnit
        case ambiguousUnits
        case nonFinite
    }

    private static let wordNumbers: [String: Double] = [
        "zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "twenty": 20,
        "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70,
        "eighty": 80, "ninety": 90,
        "hundred": 100, "thousand": 1000,
        "a": 1, "an": 1, "half": 0.5, "quarter": 0.25
    ]

    private static let poundWords: Set<String> = [
        "pound", "pounds", "lb", "lbs", "#", "octothorpe"
    ]
    private static let gramWords: Set<String> = [
        "gram", "grams", "g", "gm", "gms"
    ]

    public static func parse(_ transcript: String, locale: Locale = .current) -> Swift.Result<Result, ParseError> {
        let lower = transcript.lowercased()
        let tokens = lower
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "." && $0 != "#" })
            .map(String.init)

        var hasPound = false
        var hasGram = false
        for t in tokens {
            if poundWords.contains(t) || t.contains("#") { hasPound = true }
            if gramWords.contains(t) { hasGram = true }
        }

        let unit: MassUnit
        switch (hasPound, hasGram) {
        case (true, false): unit = .pounds
        case (false, true): unit = .grams
        case (true, true): unit = .pounds // first-wins; caller may log
        case (false, false): return .failure(.noUnit)
        }

        if let n = extractNumeric(from: tokens, locale: locale) {
            guard n.isFinite, !n.isNaN else { return .failure(.nonFinite) }
            return .success(Result(value: max(0, n), unit: unit))
        }
        if let n = extractWordNumber(from: tokens) {
            guard n.isFinite, !n.isNaN else { return .failure(.nonFinite) }
            return .success(Result(value: max(0, n), unit: unit))
        }
        return .failure(.noNumber)
    }

    private static func extractNumeric(from tokens: [String], locale: Locale) -> Double? {
        for t in tokens {
            let cleaned = t.replacingOccurrences(of: "#", with: "")
            if cleaned.isEmpty { continue }
            if let v = try? Double(cleaned, format: .number.locale(locale)) {
                return v
            }
            if let v = Double(cleaned) {
                return v
            }
        }
        return nil
    }

    private static func extractWordNumber(from tokens: [String]) -> Double? {
        var total: Double = 0
        var current: Double = 0
        var matched = false
        for t in tokens {
            guard let v = wordNumbers[t] else { continue }
            matched = true
            if v == 100 || v == 1000 {
                current = (current == 0 ? 1 : current) * v
                if v == 1000 {
                    total += current
                    current = 0
                }
            } else {
                current += v
            }
        }
        guard matched else { return nil }
        return total + current
    }
}
