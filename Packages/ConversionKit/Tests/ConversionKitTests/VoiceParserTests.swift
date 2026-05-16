@testable import ConversionKit
import Foundation
import Testing

@Suite("VoiceParser")
struct VoiceParserTests {
    @Test("digits + pounds")
    func digitsPounds() {
        let r = try? VoiceParser.parse("5 pounds").get()
        #expect(r?.value == 5)
        #expect(r?.unit == .pounds)
    }

    @Test("digits + grams")
    func digitsGrams() {
        let r = try? VoiceParser.parse("100 grams").get()
        #expect(r?.value == 100)
        #expect(r?.unit == .grams)
    }

    @Test("decimal pounds")
    func decimalPounds() {
        let r = try? VoiceParser.parse("2.5 lb").get()
        #expect(r?.value == 2.5)
        #expect(r?.unit == .pounds)
    }

    @Test("word number five pounds")
    func wordFivePounds() {
        let r = try? VoiceParser.parse("five pounds").get()
        #expect(r?.value == 5)
        #expect(r?.unit == .pounds)
    }

    @Test("word number a hundred grams")
    func aHundredGrams() {
        let r = try? VoiceParser.parse("a hundred grams").get()
        #expect(r?.value == 100)
        #expect(r?.unit == .grams)
    }

    @Test("word number twenty five pounds")
    func twentyFive() {
        let r = try? VoiceParser.parse("twenty five pounds").get()
        #expect(r?.value == 25)
        #expect(r?.unit == .pounds)
    }

    @Test("octothorpe symbol")
    func octothorpe() {
        let r = try? VoiceParser.parse("5#").get()
        #expect(r?.value == 5)
        #expect(r?.unit == .pounds)
    }

    @Test("no unit -> failure")
    func noUnit() {
        let r = VoiceParser.parse("5")
        if case let .failure(e) = r { #expect(e == .noUnit) } else { Issue.record("expected noUnit") }
    }

    @Test("no number -> failure")
    func noNumber() {
        let r = VoiceParser.parse("pounds please")
        if case let .failure(e) = r { #expect(e == .noNumber) } else { Issue.record("expected noNumber") }
    }

    @Test("empty -> failure")
    func empty() {
        let r = VoiceParser.parse("")
        if case .failure = r {} else { Issue.record("expected failure on empty") }
    }

    @Test("both units present -> pounds wins (first-wins policy)")
    func bothUnits() {
        let r = try? VoiceParser.parse("five pounds in grams").get()
        #expect(r?.unit == .pounds)
        #expect(r?.value == 5)
    }

    @Test("negative spoken value clamped")
    func negative() {
        // STT generally doesn't emit "-5" but guard regardless
        let r = try? VoiceParser.parse("-5 pounds").get()
        #expect(r?.value == 5 || r?.value == 0)
    }
}
