import BadgeKit
import SwiftUI

/// Auswahl der eingebauten Pixelsymbole. Ein Klick hängt das Kürzel an den Text
/// der ausgewählten Nachricht — im Textfeld bleibt es lesbar, auf dem Schild
/// wird daraus das Symbol.
struct IconPaletteView: View {
    let insert: (PixelIcon) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 74), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Symbol einfügen")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(PixelIcons.all) { icon in
                    Button {
                        insert(icon)
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            LEDStripView(
                                bitmap: ColumnBitmap.from(pixels: icon.pixels(rows: 11), rows: 11),
                                visibleColumns: 11,
                                dotSize: 4
                            )
                            Text(icon.germanName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 74)
                    }
                    .buttonStyle(.plain)
                    .help(icon.token)
                }
            }
            Text("Im Text steht das Kürzel, etwa \(Text(":herz:").monospaced()). Für einen echten Doppelpunkt \(Text("::").monospaced()) schreiben.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 360)
    }
}
