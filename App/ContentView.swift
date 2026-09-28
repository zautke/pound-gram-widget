import ConversionKit
import SwiftUI

struct ContentView: View {
    /// Slide-over panels opened from the toolbar.
    private enum Panel { case history, settings }

    @Binding var deepLink: DeepLink?
    @State private var showVoice = false
    @State private var panel: Panel?
    @State private var lastConversion: LastConversion? = AppSettings.restoredLastResult()
    @State private var returnedFromBackground = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("PoundsGrams")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                // Typing takes over from voice: close the voice sheet (which also stops listening).
                ConversionFieldsView(initialGrams: lastGrams) { showVoice = false }
                    .id(lastConversion?.timestamp)

                Spacer()

                Button {
                    showVoice = true
                } label: {
                    Label("Voice Convert", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("History", systemImage: "clock.arrow.circlepath") { open(.history) }
                    Button("Settings", systemImage: "gearshape") { open(.settings) }
                }
            }
            .sheet(isPresented: $showVoice) {
                // Each voice result fills the fields as soon as it's computed.
                VoiceConvertView { lastConversion = $0 }
                    .presentationDetents([.medium, .large])
                    // Keep the toolbar reachable while the voice sheet is up.
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
            .onChange(of: deepLink, initial: true) { _, new in
                guard new == .voice else { return }
                showVoice = true
                deepLink = nil
            }
            // Every launch and every return to the foreground lands in a listening voice sheet.
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .background:
                    returnedFromBackground = true
                case .active:
                    if returnedFromBackground {
                        returnedFromBackground = false
                        lastConversion = AppSettings.restoredLastResult()
                    }
                    if panel == nil { showVoice = true }
                default:
                    break
                }
            }
        }
        .overlay {
            if panel != nil {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture(perform: closePanel)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .trailing) {
            switch panel {
            case .settings:
                SettingsPanel(onClose: closePanel)
                    .transition(.move(edge: .trailing))
            case .history:
                HistoryPanel(onClose: closePanel)
                    .transition(.move(edge: .trailing))
            case nil:
                EmptyView()
            }
        }
        .animation(.snappy, value: panel)
    }

    private var lastGrams: Double? {
        guard let lc = lastConversion else { return nil }
        return lc.inputUnit == .grams ? lc.inputValue : lc.outputValue
    }

    private func open(_ newPanel: Panel) {
        showVoice = false
        panel = newPanel
    }

    /// Back to listening (with the new listen time, if it changed).
    private func closePanel() {
        panel = nil
        showVoice = true
    }
}

#Preview {
    ContentView(deepLink: .constant(nil))
}
