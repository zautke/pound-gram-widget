import SwiftUI

import ConversionKit

/// User settings, stored in standard `UserDefaults` and edited in ``SettingsPanel``.
enum AppSettings {
    static let secondsKey = "listenSeconds"
    static let defaultSeconds = 5
    /// Stored in place of a number of seconds: listen until the speaker pauses, however long that takes.
    static let indefinite = 0
    static let choices = [3, 5, 8, 10, 15]
    static let customRange = 1...600

    static let keepLastResultKey = "keepLastResult"
    static let defaultKeepLastResult = true

    /// The last result to show when the app opens, or `nil` when "Keep Last Result" is off.
    /// History is unaffected either way.
    static func restoredLastResult() -> LastConversion? {
        let keep = UserDefaults.standard.object(forKey: keepLastResultKey) as? Bool ?? defaultKeepLastResult
        return keep ? SharedStore.load() : nil
    }
}

/// Circular countdown for the current listen window.
struct CountdownRing: View {
    let deadline: Date
    let total: TimeInterval
    /// When set, the ring holds at this many seconds instead of counting down.
    var pausedRemaining: TimeInterval?

    var body: some View {
        TimelineView(.animation(paused: pausedRemaining != nil)) { context in
            let remaining = pausedRemaining ?? max(0, deadline.timeIntervalSince(context.date))
            let seconds = Int(remaining.rounded(.up))
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: total > 0 ? remaining / total : 0)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(seconds)")
                    .font(.title.monospacedDigit().bold())
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: seconds)
            }
            .frame(width: 88, height: 88)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(seconds) seconds left to speak")
        }
    }
}

/// Shown instead of ``CountdownRing`` while listening with no time limit.
struct IndefiniteRing: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(.tint, lineWidth: 8)
            Image(systemName: "infinity")
                .font(.title.bold())
                .symbolEffect(.pulse)
        }
        .frame(width: 88, height: 88)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Listening until you pause")
    }
}

/// Container for panels that slide in over the main screen from the trailing edge.
/// Close with the X, a tap on the dimmed backdrop (owned by the presenter), a swipe to the right,
/// or the VoiceOver escape gesture.
struct SlideOverPanel<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }
            .padding()

            content
        }
        .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.85, 360) }
        .frame(maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .ignoresSafeArea()
        }
        .simultaneousGesture(DragGesture().onEnded { if $0.translation.width > 60 { onClose() } })
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onClose)
    }
}

struct SettingsPanel: View {
    let onClose: () -> Void
    @AppStorage(AppSettings.secondsKey) private var listenSeconds = AppSettings.defaultSeconds
    @AppStorage(AppSettings.keepLastResultKey) private var keepLastResult = AppSettings.defaultKeepLastResult
    @State private var customText = ""
    @State private var tts = TTSService()
    @State private var isPlayingSample = false

    /// Presets, plus the current value when it was typed in as a custom time.
    private var pickerChoices: [Int] {
        AppSettings.choices.contains(listenSeconds) || listenSeconds == AppSettings.indefinite
            ? AppSettings.choices
            : (AppSettings.choices + [listenSeconds]).sorted()
    }

    var body: some View {
        SlideOverPanel(title: "Settings", onClose: onClose) {
            Form {
                Section {
                    Picker("Listen Time", selection: $listenSeconds) {
                        Text("Indefinite").tag(AppSettings.indefinite)
                        ForEach(pickerChoices, id: \.self) { Text("\($0) seconds").tag($0) }
                    }
                    LabeledContent("Custom") {
                        TextField("Seconds", text: $customText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Custom listen time in seconds")
                    }
                } footer: {
                    Text(
                        "How long PoundsGrams listens before giving up. It stops sooner once you pause. "
                            + "Indefinite waits until you speak. Custom accepts 1 to 600 seconds."
                    )
                }
                .onChange(of: customText) { _, text in
                    guard let seconds = Int(text) else { return }
                    listenSeconds = min(max(seconds, AppSettings.customRange.lowerBound), AppSettings.customRange.upperBound)
                }
                Section {
                    LabeledContent("Voice", value: TTSService.voiceDescription)
                    Button("Play Sample", systemImage: isPlayingSample ? "speaker.wave.3.fill" : "play.fill") {
                        Task {
                            isPlayingSample = true
                            await tts.speak("5 pounds is 2,267.96 grams")
                            isPlayingSample = false
                        }
                    }
                    .disabled(isPlayingSample)
                } header: {
                    Text("Voice")
                } footer: {
                    Text(
                        "Uses the best US English female voice on this iPhone. For the most natural sound, download "
                            + "Ava or Zoe (Premium) in Settings > Accessibility > Read & Speak > Voices > English, "
                            + "then reopen PoundsGrams."
                    )
                }
                Section {
                    Toggle("Keep Last Result", isOn: $keepLastResult)
                } footer: {
                    Text("Show your last conversion when PoundsGrams opens. History always keeps every conversion.")
                }
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// Every voice conversion, grouped under a header per day, newest first.
struct HistoryPanel: View {
    let onClose: () -> Void
    @State private var entries = SharedStore.history()

    private var days: [(day: Date, items: [LastConversion])] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.timestamp) }
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        SlideOverPanel(title: "History", onClose: onClose) {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No Conversions Yet",
                    systemImage: "clock",
                    description: Text("Voice conversions appear here.")
                )
            } else {
                List {
                    ForEach(days, id: \.day) { group in
                        Section(Self.header(for: group.day)) {
                            ForEach(group.items, id: \.timestamp) { item in
                                Text(item.displayString)
                                    .font(.body.monospacedDigit())
                                    .accessibilityLabel(item.accessibilityString)
                            }
                            // Swipe left to delete (VoiceOver: the row's Delete action).
                            .onDelete { offsets in
                                for item in offsets.map({ group.items[$0] }) {
                                    SharedStore.deleteFromHistory(item)
                                }
                                withAnimation { entries = SharedStore.history() }
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
    }

    private static func header(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }
}
