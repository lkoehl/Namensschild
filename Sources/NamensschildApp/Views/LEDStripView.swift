import BadgeKit
import SwiftUI

/// Ruhende Miniaturansicht einer Bitmap — für die Zeilenliste und den Schriftwähler.
/// Ist der Inhalt breiter als der Platz, blendet der rechte Rand aus, statt
/// den Text hart abzuschneiden.
struct LEDStripView: View {
    let bitmap: ColumnBitmap
    var visibleColumns: Int = 88
    var dotSize: CGFloat = 2

    private var isTruncated: Bool { bitmap.pixelWidth > visibleColumns }

    var body: some View {
        Canvas { canvas, size in
            let cell = min(size.width / CGFloat(visibleColumns), size.height / CGFloat(max(bitmap.rows, 1)))
            let dot = cell * 0.8
            let originY = (size.height - cell * CGFloat(bitmap.rows)) / 2
            for row in 0..<bitmap.rows {
                for column in 0..<visibleColumns where bitmap[column, row] {
                    let rect = CGRect(
                        x: CGFloat(column) * cell + (cell - dot) / 2,
                        y: originY + CGFloat(row) * cell + (cell - dot) / 2,
                        width: dot, height: dot
                    )
                    canvas.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.36, green: 0.72, blue: 1)))
                }
            }
        }
        .frame(width: CGFloat(visibleColumns) * dotSize, height: CGFloat(bitmap.rows) * dotSize)
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
        .mask(
            LinearGradient(
                stops: isTruncated
                    ? [.init(color: .black, location: 0), .init(color: .black, location: 0.86),
                       .init(color: .black.opacity(0.15), location: 1)]
                    : [.init(color: .black, location: 0), .init(color: .black, location: 1)],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .help(isTruncated ? "Läuft über die Anzeigebreite hinaus — das Schild scrollt." : "")
    }
}
