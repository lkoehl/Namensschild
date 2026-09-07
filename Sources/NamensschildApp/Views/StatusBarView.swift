import BadgeKit
import SwiftUI

/// Fußzeile: Verbindung, Speicherbedarf, Rückmeldung und die beiden Knöpfe.
struct StatusBarView: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            connection
            Divider().frame(height: 26)
            budget
            Spacer(minLength: 12)
            statusText
            Button("Testmuster") { model.sendTestPattern() }
                .disabled(!model.isConnected || model.isSending)
                .help("Alle LEDs einschalten — so lässt sich die Zeilenzahl abzählen")
            Button {
                model.send()
            } label: {
                if model.isSending {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Senden")
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canSend)
        }
    }

    private var connection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.isConnected ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.isConnected ? "Schild verbunden" : "Kein Schild")
                    .font(.callout)
                if let device = model.connectedDevices.first {
                    Text(device.displayName).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("USB-Kabel prüfen").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .fixedSize()
    }

    private var budget: some View {
        VStack(alignment: .leading, spacing: 3) {
            ProgressView(value: min(Double(model.usedColumns), Double(model.columnBudget)),
                         total: Double(model.columnBudget))
                .progressViewStyle(.linear)
                .frame(width: 140)
                .tint(model.overBudget ? .red : .accentColor)
            Text("\(model.usedColumns) / \(model.columnBudget) Byte-Spalten")
                .font(.caption2)
                .foregroundStyle(model.overBudget ? Color.red : .secondary)
                .monospacedDigit()
        }
        .fixedSize()
        .help("Alle acht Nachrichten zusammen passen in 8 KB Gerätespeicher.")
    }

    @ViewBuilder
    private var statusText: some View {
        if let message = model.status.message {
            Label(message, systemImage: icon)
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(2)
                .frame(maxWidth: 320, alignment: .trailing)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }

    private var icon: String {
        switch model.status {
        case .failure: return "exclamationmark.triangle.fill"
        case .success: return "checkmark.circle.fill"
        default:       return "arrow.up.circle"
        }
    }

    private var color: Color {
        switch model.status {
        case .failure: return .red
        case .success: return .green
        default:       return .secondary
        }
    }
}
