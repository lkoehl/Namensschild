import BadgeKit
import SwiftUI

struct MessageListView: View {
    @Bindable var model: AppModel

    private let numberWidth: CGFloat = 26
    private let effectWidth: CGFloat = 132
    private let speedWidth: CGFloat = 56
    private let toggleWidth: CGFloat = 58

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
        let columns = model.bitmap(for: index).byteColumns

        return HStack(spacing: 8) {
            Toggle("", isOn: message.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 18)
                .help("Nachricht \(index + 1) auf das Schild übertragen")

            Text("M\(index + 1)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .frame(width: numberWidth, alignment: .leading)

            TextField("Text für Platz \(index + 1)", text: message.text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)

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
        .background(isSelected ? Color.accentColor.opacity(0.10) : .clear)
        .contentShape(Rectangle())
        .onTapGesture { model.selectedSlot = index }
        .help(columns > 0 ? "\(columns) Byte-Spalten" : "leer")
    }
}
