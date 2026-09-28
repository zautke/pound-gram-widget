import ConversionKit
import SwiftUI

struct ContentView: View {
    @Binding var deepLink: DeepLink?
    @State private var showVoice = false
    @State private var lastConversion: LastConversion? = SharedStore.load()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("PoundsGrams")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                ConversionFieldsView(initialGrams: lastGrams)
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
            .sheet(isPresented: $showVoice, onDismiss: reload) {
                VoiceConvertView()
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: deepLink, initial: true) { _, new in
                guard new == .voice else { return }
                showVoice = true
                deepLink = nil
            }
            // Every launch and every return to the foreground lands in a listening voice sheet.
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                reload()
                showVoice = true
            }
        }
    }

    private var lastGrams: Double? {
        guard let lc = lastConversion else { return nil }
        return lc.inputUnit == .grams ? lc.inputValue : lc.outputValue
    }

    private func reload() {
        let latest = SharedStore.load()
        if latest != lastConversion { lastConversion = latest }
    }
}

#Preview {
    ContentView(deepLink: .constant(nil))
}
