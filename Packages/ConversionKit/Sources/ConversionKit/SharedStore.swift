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
    /// WidgetKit kind shared by the widget and the app's reload calls.
    public static let widgetKind = "PoundsGramsWidget"
    /// Deep link that opens the voice converter and starts listening.
    public static let voiceURL = URL(string: "poundsgrams://voice")!

    private static func defaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    public static func save(_ conversion: LastConversion) {
        guard let data = try? JSONEncoder().encode(conversion) else { return }
        defaults().set(data, forKey: lastConversionKey)
    }

    public static func load() -> LastConversion? {
        guard let data = defaults().data(forKey: lastConversionKey) else { return nil }
        return try? JSONDecoder().decode(LastConversion.self, from: data)
    }

    public static func clear() {
        defaults().removeObject(forKey: lastConversionKey)
    }
}
