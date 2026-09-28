import Foundation

public struct LastConversion: Codable, Sendable, Equatable {
    public let inputValue: Double
    public let inputUnit: MassUnit
    public let outputValue: Double
    public let outputUnit: MassUnit
    public let timestamp: Date

    public init(
        inputValue: Double,
        inputUnit: MassUnit,
        outputValue: Double,
        outputUnit: MassUnit,
        timestamp: Date = .now
    ) {
        self.inputValue = inputValue
        self.inputUnit = inputUnit
        self.outputValue = outputValue
        self.outputUnit = outputUnit
        self.timestamp = timestamp
    }

    public var displayString: String {
        let inputStr = inputUnit == .pounds
            ? MassConverter.formatPounds(inputValue)
            : MassConverter.formatGrams(inputValue)
        let outputStr = outputUnit == .pounds
            ? MassConverter.formatPounds(outputValue)
            : MassConverter.formatGrams(outputValue)
        return "\(inputStr) = \(outputStr)"
    }

    public var accessibilityString: String {
        let inStr = MassConverter.spokenString(inputValue, unit: inputUnit)
        let outStr = MassConverter.spokenString(outputValue, unit: outputUnit)
        return "\(inStr) equals \(outStr)"
    }
}

extension MassUnit: Codable {}

public enum SharedStore {
    public static let appGroupID = "group.com.braisenly.pounds-grams"
    public static let lastConversionKey = "lastConversion"
    public static let historyKey = "conversionHistory"
    /// ponytail: history is one JSON array in UserDefaults, capped here. Move to SwiftData if it
    /// ever needs search, sync, or unbounded size.
    public static let historyLimit = 1000
    /// WidgetKit kind shared by the widget and the app's reload calls.
    public static let widgetKind = "PoundsGramsWidget"
    /// Deep link that opens the voice converter and starts listening.
    public static let voiceURL = URL(string: "poundsgrams://voice")!

    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Stores `conversion` as the last result and prepends it to the history.
    public static func save(_ conversion: LastConversion) {
        guard let data = try? JSONEncoder().encode(conversion) else { return }
        defaults().set(data, forKey: lastConversionKey)
        let updated = Array(([conversion] + history()).prefix(historyLimit))
        if let historyData = try? JSONEncoder().encode(updated) {
            defaults().set(historyData, forKey: historyKey)
        }
    }

    /// Every saved conversion, newest first.
    public static func history() -> [LastConversion] {
        guard let data = defaults().data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([LastConversion].self, from: data)) ?? []
    }

    public static func load() -> LastConversion? {
        guard let data = defaults().data(forKey: lastConversionKey) else { return nil }
        return try? JSONDecoder().decode(LastConversion.self, from: data)
    }

    /// Removes one entry from the history. The last result is left alone.
    public static func deleteFromHistory(_ conversion: LastConversion) {
        let remaining = history().filter { $0 != conversion }
        if let data = try? JSONEncoder().encode(remaining) {
            defaults().set(data, forKey: historyKey)
        }
    }

    /// Removes the last result and the history.
    public static func clear() {
        defaults().removeObject(forKey: lastConversionKey)
        defaults().removeObject(forKey: historyKey)
    }
}
