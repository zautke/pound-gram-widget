import ConversionKit
import SwiftUI
import WidgetKit

struct PoundsGramsEntry: TimelineEntry {
    let date: Date
    let last: LastConversion?
}

struct PoundsGramsProvider: TimelineProvider {
    func placeholder(in _: Context) -> PoundsGramsEntry {
        PoundsGramsEntry(date: .now, last: nil)
    }

    func getSnapshot(in _: Context, completion: @escaping (PoundsGramsEntry) -> Void) {
        completion(PoundsGramsEntry(date: .now, last: SharedStore.load()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<PoundsGramsEntry>) -> Void) {
        let entry = PoundsGramsEntry(date: .now, last: SharedStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct PoundsGramsWidgetView: View {
    var entry: PoundsGramsEntry

    var body: some View {
        Button(intent: LaunchVoiceIntent()) {
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "mic.fill")
                        .accessibilityHidden(true)
                    Text("Tap to convert")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)

                if let lc = entry.last {
                    Text(lc.displayString)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Say \u{201C}5 pounds\u{201D} or \u{201C}100 grams\u{201D}")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.last.map { "Voice convert. Last: \($0.accessibilityString)" }
            ?? "Voice convert. Say a value like 5 pounds or 100 grams.")
        .accessibilityHint("Opens voice converter")
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct PoundsGramsWidget: Widget {
    let kind = "PoundsGramsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PoundsGramsProvider()) { entry in
            PoundsGramsWidgetView(entry: entry)
        }
        .configurationDisplayName("PoundsGrams")
        .description("Tap to voice-convert pounds and grams.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    PoundsGramsWidget()
} timeline: {
    PoundsGramsEntry(date: .now, last: nil)
    PoundsGramsEntry(date: .now, last: LastConversion(
        inputValue: 5, inputUnit: .pounds,
        outputValue: 2267.96185, outputUnit: .grams
    ))
}
