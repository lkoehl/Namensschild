import BadgeKit
import SwiftUI

struct ContentView: View {
    @Bindable var model: AppModel

    private var selected: BadgeMessage { model.document.messages[model.selectedSlot] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            preview
            MessageListView(model: model)
            appearance
            Divider()
            StatusBarView(model: model)
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 620)
        .onChange(of: model.document) { model.documentDidChange() }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 6) {
            LEDPreviewView(
                bitmap: model.bitmap(for: model.selectedSlot),
                effect: selected.effect,
                speed: selected.speed,
                blink: selected.blink,
                border: selected.border,
                columns: model.displayColumns,
                brightness: model.document.brightness
            )
            .frame(maxWidth: .infinity)
            .frame(height: 132)

            HStack {
                Text("Vorschau M\(model.selectedSlot + 1) · \(selected.effect.germanName)")
                if !isAnimatedHere(selected.effect) {
                    Text("— diesen Effekt spielt das Schild selbst ab")
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(model.displayColumns) × \(model.document.rowCount.rawValue) Pixel")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func isAnimatedHere(_ effect: BadgeEffect) -> Bool {
        switch effect {
        case .scrollLeft, .scrollRight, .scrollUp, .scrollDown, .still: return true
        default: return false
        }
    }

    private var appearance: some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Picker("Schrift", selection: $model.document.fontName) {
                ForEach(TextRasterizer.recommendedFonts, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .frame(width: 240)

            HStack(spacing: 4) {
                Text("Größe")
                TextField("", value: $model.document.fontSize, format: .number.precision(.fractionLength(0)))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 46)
                    .multilineTextAlignment(.trailing)
                Stepper("", value: $model.document.fontSize, in: 6...24, step: 1)
                    .labelsHidden()
            }

            Picker("Helligkeit", selection: $model.document.brightness) {
                ForEach(BadgeBrightness.allCases, id: \.self) { level in
                    Text(level.germanName).tag(level)
                }
            }
            .frame(width: 160)

            Picker("Modell", selection: $model.document.rowCount) {
                ForEach(BadgeRowCount.allCases, id: \.self) { rows in
                    Text("\(rows.rawValue) Zeilen").tag(rows)
                }
            }
            .frame(width: 150)
            .help("11 Zeilen: S1144/B1144/GD1144 · 12 Zeilen: S1248/B1248/GD1248.\nIm Zweifel „Testmuster“ senden und die Reihen abzählen.")

            Spacer()

            if !model.fontFits {
                fontWarning
            }
        }
        .font(.callout)
    }

    /// Bei zu großer Schrift schneidet das Schild etwas ab — meist zuerst die
    /// Unterlängen. Lieber einmal darauf hinweisen, als es hinterher zu sehen.
    private var fontWarning: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text("Schrift zu groß")
                Text("Unterlängen werden abgeschnitten")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button("Auf \(Int(model.largestFittingFontSize)) pt") { model.shrinkFontToFit() }
                .controlSize(.small)
        }
        .font(.caption)
        .fixedSize()
    }
}
