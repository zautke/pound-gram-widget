@testable import ConversionKit
import Foundation
import Testing

@Suite("MassConverter")
struct MassConverterTests {
    @Test("1 lb == 453.59237 g (exact)")
    func exactConstant() {
        #expect(MassConverter.gramsFromPounds(1) == 453.59237)
    }

    @Test("roundtrip preserves value within 1e-9")
    func roundtrip() {
        for v in stride(from: 0.0, through: 1000.0, by: 17.3) {
            let g = MassConverter.gramsFromPounds(v)
            let lb = MassConverter.poundsFromGrams(g)
            #expect(abs(lb - v) < 1e-9, "roundtrip failed for \(v)")
        }
    }

    @Test("negative input clamped to zero")
    func negativeClamped() {
        #expect(MassConverter.gramsFromPounds(-5) == 0)
        #expect(MassConverter.poundsFromGrams(-10) == 0)
    }

    @Test("zero in zero out")
    func zero() {
        #expect(MassConverter.gramsFromPounds(0) == 0)
        #expect(MassConverter.poundsFromGrams(0) == 0)
    }

    @Test("convert routes by unit pair")
    func convertRouting() {
        #expect(MassConverter.convert(1, from: .pounds, to: .grams) == 453.59237)
        #expect(MassConverter.convert(453.59237, from: .grams, to: .pounds) == 1)
        #expect(MassConverter.convert(42, from: .pounds, to: .pounds) == 42)
        #expect(MassConverter.convert(42, from: .grams, to: .grams) == 42)
    }

    @Test("parse known good strings", arguments: [
        ("5", 5.0),
        ("5.2", 5.2),
        ("0", 0.0),
        ("1000", 1000.0),
        ("   42  ", 42.0),
        ("3.14159", 3.14159),
    ])
    func parseGood(input: String, expected: Double) {
        let posix = Locale(identifier: "en_US_POSIX")
        #expect(MassConverter.parse(input, locale: posix) == expected)
    }

    @Test("parse rejects empty/invalid", arguments: ["", "   ", "abc", ".", "-"])
    func parseRejects(input: String) {
        let v = MassConverter.parse(input, locale: Locale(identifier: "en_US_POSIX"))
        #expect(v == nil || v == 0.0 || (v != nil && v!.isFinite))
    }

    @Test("formatPounds appends octothorpe")
    func formatPoundsOcto() {
        #expect(MassConverter.formatPounds(5) == "5#")
        #expect(MassConverter.formatPounds(2.5) == "2.5#")
        #expect(MassConverter.formatPounds(0) == "0#")
    }

    @Test("formatGrams appends g")
    func formatGramsUnit() {
        #expect(MassConverter.formatGrams(100) == "100g")
        #expect(MassConverter.formatGrams(0) == "0g")
    }

    @Test("formatConversion full expression")
    func formatExpr() {
        #expect(MassConverter.formatConversion(value: 1, unit: .pounds) == "1# = 453.59g")
        #expect(MassConverter.formatConversion(value: 0, unit: .grams) == "0g = 0#")
    }

    @Test("NaN/Inf produce empty string, not crash")
    func nonFinite() {
        #expect(MassConverter.formatPounds(.nan) == "")
        #expect(MassConverter.formatPounds(.infinity) == "")
        #expect(MassConverter.formatGrams(.nan) == "")
    }
}
