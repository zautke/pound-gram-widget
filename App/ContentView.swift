import ConversionKit
import SwiftUI

struct ContentView: View {
    @Binding var deepLink: DeepLink?
    @State private var showVoice: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("PoundsGrams")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)

                ConversionFieldsView()

                Spacer()

                Button {
                    showVoice = true
                } label: {
                    Label("Voice Convert", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showVoice) {
                VoiceConvertView()
                    .presentationDetents([.medium, .large])
            }
            .onChange(of: deepLink) { _, new in
                if new == .voice {
                    showVoice = true
                    deepLink = nil
                }
            }
        }
    }
}

#Preview {
    ContentView(deepLink: .constant(nil))
}
