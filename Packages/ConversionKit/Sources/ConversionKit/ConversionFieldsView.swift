#if os(iOS)
    import SwiftUI
    import UIKit

    public struct ConversionFieldsView: View {
        public enum Field: Hashable { case pounds, grams }

        @State private var poundsText: String = ""
        @State private var gramsText: String = ""
        @FocusState private var focused: Field?
        @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44

        public init(initialGrams: Double? = nil) {
            if let g = initialGrams, g.isFinite {
                _gramsText = State(initialValue: MassConverter.displayString(g))
                _poundsText = State(initialValue: MassConverter.displayString(MassConverter.poundsFromGrams(g)))
            }
        }

        public var body: some View {
            VStack(spacing: 16) {
                row(label: "Pounds (#)", text: $poundsText, field: .pounds, keyboard: .decimalPad)
                    .accessibilityLabel("Pounds")
                    .accessibilityValue(poundsText.isEmpty ? "empty" : poundsText)

                row(label: "Grams (g)", text: $gramsText, field: .grams, keyboard: .decimalPad)
                    .accessibilityLabel("Grams")
                    .accessibilityValue(gramsText.isEmpty ? "empty" : gramsText)
            }
            .padding()
            .onChange(of: poundsText) { _, new in
                guard focused == .pounds else { return }
                propagate(from: .pounds, text: new)
            }
            .onChange(of: gramsText) { _, new in
                guard focused == .grams else { return }
                propagate(from: .grams, text: new)
            }
        }

        private func row(label: String, text: Binding<String>, field: Field, keyboard: UIKeyboardType) -> some View {
            HStack {
                Text(label)
                    .frame(width: 100, alignment: .leading)
                    .font(.headline)
                TextField("0", text: text)
                    .keyboardType(keyboard)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused, equals: field)
                    .frame(minHeight: rowHeight)
                    .submitLabel(.done)
            }
        }

        private func propagate(from source: Field, text raw: String) {
            guard let value = MassConverter.parse(raw) else {
                if raw.isEmpty {
                    switch source {
                    case .pounds: gramsText = ""
                    case .grams: poundsText = ""
                    }
                }
                return
            }
            switch source {
            case .pounds:
                let g = MassConverter.gramsFromPounds(value)
                gramsText = MassConverter.displayString(g)
            case .grams:
                let lb = MassConverter.poundsFromGrams(value)
                poundsText = MassConverter.displayString(lb)
            }
        }
    }

    #Preview {
        ConversionFieldsView()
    }
#endif
