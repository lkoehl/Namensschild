import BadgeKit
import SwiftUI

/// Zeigt den Inhalt auf einem Raster in der Geometrie des echten Schilds.
/// Die vier Laufrichtungen werden animiert; die übrigen Effekte erzeugt die
/// Firmware selbst und werden hier ruhend dargestellt.
struct LEDPreviewView: View {
    let bitmap: ColumnBitmap
    let effect: BadgeEffect
    let speed: Int
    let blink: Bool
    let border: Bool
    let columns: Int
    let brightness: BadgeBrightness

    private var rows: Int { bitmap.rows }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                draw(in: &canvas, size: size, time: context.date.timeIntervalSinceReferenceDate)
            }
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
        .aspectRatio(CGFloat(columns) / CGFloat(max(rows, 1)) * 1.05, contentMode: .fit)
        .accessibilityLabel("Vorschau des Schildinhalts")
    }

    private func draw(in canvas: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let cell = min(size.width / CGFloat(columns), size.height / CGFloat(max(rows, 1)))
        let dot = cell * 0.78
        let originX = (size.width - cell * CGFloat(columns)) / 2
        let originY = (size.height - cell * CGFloat(rows)) / 2

        let dim = Color(red: 0.09, green: 0.11, blue: 0.16)
        let lit = Color(red: 0.31, green: 0.68, blue: 1.0)
        let intensity = 0.35 + 0.65 * (Double(brightness.rawValue) / 100.0)
        let visible = !blink || time.truncatingRemainder(dividingBy: 1.0) < 0.62
        let shift = offset(at: time)

        for row in 0..<rows {
            for column in 0..<columns {
                let rect = CGRect(
                    x: originX + CGFloat(column) * cell + (cell - dot) / 2,
                    y: originY + CGFloat(row) * cell + (cell - dot) / 2,
                    width: dot, height: dot
                )
                let on = visible && isLit(column: column, row: row, shift: shift, time: time)
                if on {
                    canvas.fill(Path(ellipseIn: rect.insetBy(dx: -dot * 0.28, dy: -dot * 0.28)),
                                with: .color(lit.opacity(0.20 * intensity)))
                    canvas.fill(Path(ellipseIn: rect), with: .color(lit.opacity(intensity)))
                } else {
                    canvas.fill(Path(ellipseIn: rect), with: .color(dim))
                }
            }
        }
    }

    private func isLit(column: Int, row: Int, shift: CGSize, time: TimeInterval) -> Bool {
        if border, isBorderCell(column: column, row: row, time: time) { return true }
        let x = column - Int(shift.width.rounded())
        let y = row - Int(shift.height.rounded())
        return bitmap[x, y]
    }

    /// Das Lauflicht am Rand — beim Gerät „Ants", eine umlaufende Punktkette.
    private func isBorderCell(column: Int, row: Int, time: TimeInterval) -> Bool {
        let onEdge = row == 0 || row == rows - 1 || column == 0 || column == columns - 1
        guard onEdge else { return false }
        let step = Int(time * 8)
        let position: Int
        if row == 0 { position = column }
        else if column == columns - 1 { position = columns + row }
        else if row == rows - 1 { position = columns + rows + (columns - 1 - column) }
        else { position = 2 * columns + rows + (rows - 1 - row) }
        return (position + step) % 4 < 2
    }

    private func offset(at time: TimeInterval) -> CGSize {
        let pixelsPerSecond = Double(min(max(speed, 1), 8)) * 6 + 6
        let width = bitmap.pixelWidth

        switch effect {
        case .scrollLeft, .laser, .animation:
            guard width > 0 else { return .zero }
            let span = Double(width + columns)
            let progress = (time * pixelsPerSecond).truncatingRemainder(dividingBy: span)
            return CGSize(width: Double(columns) - progress, height: 0)
        case .scrollRight:
            guard width > 0 else { return .zero }
            let span = Double(width + columns)
            let progress = (time * pixelsPerSecond).truncatingRemainder(dividingBy: span)
            return CGSize(width: progress - Double(width), height: 0)
        case .scrollUp:
            let span = Double(rows * 2)
            let progress = (time * pixelsPerSecond / 4).truncatingRemainder(dividingBy: span)
            return CGSize(width: centeredX, height: Double(rows) - progress)
        case .scrollDown:
            let span = Double(rows * 2)
            let progress = (time * pixelsPerSecond / 4).truncatingRemainder(dividingBy: span)
            return CGSize(width: centeredX, height: progress - Double(rows))
        case .still, .dropDown, .curtain:
            return CGSize(width: centeredX, height: 0)
        }
    }

    /// Passt der Inhalt aufs Display, wird er zentriert — sonst linksbündig.
    private var centeredX: Double {
        let width = bitmap.pixelWidth
        return width < columns ? Double((columns - width) / 2) : 0
    }
}
