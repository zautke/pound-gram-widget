#if os(iOS)
    import SwiftUI

    public struct ConversionFieldsView: View {
        public enum Field: Hashable { case pounds, grams }

        @State private var poundsText: String = ""
        @State private var gramsText: String = ""
        @FocusState private var focused: Field?
        @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 44
        private let onBeginEditing: () -> Void

        /// - Parameter onBeginEditing: Called when the user taps into the fields from elsewhere.
        public init(initialGrams: Double? = nil, onBeginEditing: @escaping () -> Void = {}) {
            self.onBeginEditing = onBeginEditing
            if let g = initialGrams, g.isFinite {
                _gramsText = State(initialValue: MassConverter.displayString(g))
                _poundsText = State(initialValue: MassConverter.displayString(MassConverter.poundsFromGrams(g)))
            }
        }

        public var body: some View {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 16) {
                row(label: "Pounds (#)", a11yLabel: "Pounds", text: $poundsText, field: .pounds)
                row(label: "Grams (g)", a11yLabel: "Grams", text: $gramsText, field: .grams)
            }
            .padding()
            // Tapping into the fields starts a fresh conversion: clear the previous values.
            // Moving between the two fields keeps what was typed.
            .onChange(of: focused) { old, new in
                guard old == nil, new != nil else { return }
                onBeginEditing()
                poundsText = ""
                gramsText = ""
            }
            .onChange(of: poundsText) { _, new in
                guard focused == .pounds else { return }
                propagate(from: .pounds, text: new)
            }
            .onChange(of: gramsText) { _, new in
                guard focused == .grams else { return }
                propagate(from: .grams, text: new)
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = nil }
                }
            }
        }

        private func row(label: String, a11yLabel: String, text: Binding<String>, field: Field) -> some View {
            GridRow {
                Text(label)
                    .font(.headline)
                    .accessibilityHidden(true)
                TextField("0", text: text)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused, equals: field)
                    .frame(minHeight: rowHeight)
                    .accessibilityLabel(a11yLabel)
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
