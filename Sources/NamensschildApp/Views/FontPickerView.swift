import AppKit
import BadgeKit
import SwiftUI

/// Schriftwähler mit echter Vorschau: jede Schrift wird auf demselben Punktraster
/// gezeigt, auf dem sie später landet. Bei elf Zeilen sieht man erst dort, ob eine
/// Schrift taugt — der Name allein sagt darüber nichts.
struct FontPickerView: View {
    let rows: Int
    let size: Double
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    @State private var search = ""
    @State private var candidates: [String] = []
    @State private var isLoading = true

    private let sample = "Hallo Köln 123"

    private var shown: [String] {
        guard !search.isEmpty else { return candidates }
        return candidates.filter { $0.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Schrift wählen").font(.headline)
                Spacer()
                Button("Fertig") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(12)

            TextField("Suchen", text: $search)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

            Divider()

            if isLoading {
                ProgressView("Schriften prüfen …")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(shown, id: \.self, selection: $selection) { name in
                    row(name)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = name }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 460, height: 520)
        .task { await load() }
    }

    private func row(_ name: String) -> some View {
        let rasterizer = TextRasterizer(fontName: name, fontSize: size, rows: rows)
        return HStack(spacing: 10) {
            Image(systemName: selection == name ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selection == name ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(.callout)
                    if !rasterizer.fitsRows {
                        Text("zu groß")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.orange.opacity(0.22), in: Capsule())
                    }
                }
                LEDStripView(bitmap: rasterizer.rasterize(sample), visibleColumns: 110, dotSize: 2.4)
            }
        }
        .padding(.vertical, 3)
    }

    /// Viele installierte Schriften enthalten kein lateinisches Alphabet oder
    /// rastern auf diesem Raster zu nichts. Die fliegen hier raus, statt die
    /// Liste mit leeren Zeilen zu füllen.
    private func load() async {
        guard candidates.isEmpty else { return }
        let families = NSFontManager.shared.availableFontFamilies
        let rows = rows
        let size = size
        let usable = await Task.detached(priority: .userInitiated) { () -> [String] in
            families.filter { family in
                let bitmap = TextRasterizer(fontName: family, fontSize: size, rows: rows).rasterize("Hallo")
                return bitmap.byteColumns > 0 && bitmap.bytes.contains { $0 != 0 }
            }
        }.value
        candidates = (TextRasterizer.recommendedFonts + usable.filter { !TextRasterizer.recommendedFonts.contains($0) })
        isLoading = false
    }
}
