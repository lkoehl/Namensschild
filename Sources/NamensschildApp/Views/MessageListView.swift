import BadgeKit
import SwiftUI
import UniformTypeIdentifiers

struct MessageListView: View {
    @Bindable var model: AppModel

    @State private var dragging: Int?
    @State private var dropTarget: Int?

    private let numberWidth: CGFloat = 26
    private let previewWidth: CGFloat = 124
    private let effectWidth: CGFloat = 128
    private let speedWidth: CGFloat = 54
    private let toggleWidth: CGFloat = 56

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ForEach(Array(model.document.messages.indices), id: \.self) { index in
                row(index)
                if index < model.document.messages.count - 1 {
                    Divider().opacity(0.4)
                }
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("").frame(width: 18)
            Text("Nr").frame(width: numberWidth, alignment: .leading)
            Text("Text").frame(maxWidth: .infinity, alignment: .leading)
            Text("Vorschau").frame(width: previewWidth, alignment: .leading)
            Text("Effekt").frame(width: effectWidth, alignment: .leading)
            Text("Tempo").frame(width: speedWidth, alignment: .leading)
            Text("Blinken").frame(width: toggleWidth, alignment: .center)
            Text("Rahmen").frame(width: toggleWidth, alignment: .center)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private func row(_ index: Int) -> some View {
        let message = $model.document.messages[index]
        let isSelected = model.selectedSlot == index
        let bitmap = model.bitmap(for: index)
        let hasContent = model.document.messages[index].carriesContent

        return HStack(spacing: 8) {
            Toggle("", isOn: message.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 18)
                .help("Nachricht \(index + 1) auf das Schild übertragen")

            // Griff zum Umsortieren. Bewusst nur die Nummer und nicht die ganze
            // Zeile — sonst ließe sich im Textfeld nichts mehr markieren.
            Text("M\(index + 1)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: numberWidth, alignment: .leading)
                .contentShape(Rectangle())
                .onDrag {
                    dragging = index
                    return NSItemProvider(object: String(index) as NSString)
                }
                .help("Ziehen, um die Nachricht auf einen anderen Platz zu legen")

            TextField("Text für Platz \(index + 1)", text: message.text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
                .onTapGesture { model.selectedSlot = index }

            Group {
                if hasContent {
                    LEDStripView(bitmap: bitmap, visibleColumns: 56, dotSize: 2.1)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .frame(width: previewWidth, alignment: .leading)
            .opacity(message.wrappedValue.isEnabled ? 1 : 0.45)

            Picker("", selection: message.effect) {
                ForEach(BadgeEffect.allCases, id: \.self) { effect in
                    Text(effect.germanName).tag(effect)
                }
            }
            .labelsHidden()
            .frame(width: effectWidth)

            Picker("", selection: message.speed) {
                ForEach(1...8, id: \.self) { Text("\($0)").tag($0) }
            }
            .labelsHidden()
            .frame(width: speedWidth)

            Toggle("", isOn: message.blink)
                .labelsHidden().toggleStyle(.checkbox)
                .frame(width: toggleWidth, alignment: .center)

            Toggle("", isOn: message.border)
                .labelsHidden().toggleStyle(.checkbox)
                .frame(width: toggleWidth, alignment: .center)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background(isSelected: isSelected, index: index))
        .overlay(alignment: .top) {
            if dropTarget == index, dragging != index {
                Rectangle().fill(Color.accentColor).frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.selectedSlot = index }
        // Die Plätze entsprechen den Tasten M1 bis M8 am Schild — Umsortieren
        // heißt also, den Inhalt auf eine andere Taste zu legen.
        .onDrop(of: [UTType.text], delegate: RowDropDelegate(
            index: index,
            dragging: $dragging,
            dropTarget: $dropTarget,
            move: { from, to in model.moveMessage(from: from, to: to) }
        ))
        .help(bitmap.byteColumns > 0 ? "\(bitmap.byteColumns) Byte-Spalten" : "leer")
    }

    private func background(isSelected: Bool, index: Int) -> some View {
        Group {
            if dragging == index {
                Color.accentColor.opacity(0.05)
            } else if isSelected {
                Color.accentColor.opacity(0.10)
            } else {
                Color.clear
            }
        }
    }
}

private struct RowDropDelegate: DropDelegate {
    let index: Int
    @Binding var dragging: Int?
    @Binding var dropTarget: Int?
    let move: (Int, Int) -> Void

    func dropEntered(info: DropInfo) { dropTarget = index }
    func dropExited(info: DropInfo) { if dropTarget == index { dropTarget = nil } }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        defer { dragging = nil; dropTarget = nil }
        guard let source = dragging, source != index else { return false }
        move(source, source < index ? index + 1 : index)
        return true
    }
}
