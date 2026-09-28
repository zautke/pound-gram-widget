@testable import ConversionKit
import Foundation
import Testing

@Suite("SharedStore + LastConversion")
struct SharedStoreTests {
    @Test("save records history newest first and keeps the last result")
    func history() {
        SharedStore.clear()
        let first = LastConversion(inputValue: 1, inputUnit: .pounds, outputValue: 453.59237, outputUnit: .grams,
                                   timestamp: Date(timeIntervalSince1970: 1))
        let second = LastConversion(inputValue: 100, inputUnit: .grams, outputValue: 0.2205, outputUnit: .pounds,
                                    timestamp: Date(timeIntervalSince1970: 2))
        SharedStore.save(first)
        SharedStore.save(second)
        #expect(SharedStore.history() == [second, first])
        #expect(SharedStore.load() == second)

        SharedStore.deleteFromHistory(second)
        #expect(SharedStore.history() == [first])
        #expect(SharedStore.load() == second)
        SharedStore.clear()
    }

    @Test("LastConversion encodes/decodes roundtrip")
    func codable() throws {
        let original = LastConversion(
            inputValue: 5,
            inputUnit: .pounds,
            outputValue: 2267.96185,
            outputUnit: .grams
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LastConversion.self, from: data)
        #expect(decoded.inputValue == original.inputValue)
        #expect(decoded.inputUnit == original.inputUnit)
        #expect(decoded.outputValue == original.outputValue)
        #expect(decoded.outputUnit == original.outputUnit)
    }

    @Test("displayString uses octothorpe for pounds")
    func displayPounds() {
        let lc = LastConversion(
            inputValue: 5,
            inputUnit: .pounds,
            outputValue: 2267.96185,
            outputUnit: .grams
        )
        #expect(lc.displayString.contains("5#"))
        #expect(lc.displayString.contains("g"))
        #expect(lc.displayString.contains(" = "))
    }

    @Test("displayString g→# direction")
    func displayGrams() {
        let lc = LastConversion(
            inputValue: 1000,
            inputUnit: .grams,
            outputValue: 2.20462,
            outputUnit: .pounds
        )
        let s = lc.displayString.replacingOccurrences(of: ",", with: "")
        #expect(s.hasPrefix("1000g"))
        #expect(s.contains("#"))
        #expect(s.contains(" = "))
    }
}
