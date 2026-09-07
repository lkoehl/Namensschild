import CoreGraphics
import CoreText
import Foundation

/// Rendert Text über CoreText in eine LED-Bitmap.
///
/// Antialiasing ist bewusst abgeschaltet: bei elf Pixeln Höhe gibt es keine
/// Graustufen, jedes Pixel ist an oder aus. Der Schwellwert entscheidet, ab
/// welcher Deckung ein Pixel als „an" gilt.
public struct TextRasterizer: Sendable {
    public static let defaultFontName = "Menlo-Bold"
    public static let defaultFontSize: Double = 10

    /// Diese Zeichen legen zusammen fest, wie hoch eine Zeile werden kann:
    /// große Umlaute reichen am weitesten nach oben, g/j/p/q am weitesten nach unten.
    /// Die Grundlinie wird aus ihnen abgeleitet, damit sie über alle Nachrichten
    /// hinweg gleich bleibt — und damit nichts oben abgeschnitten wird.
    static let extremeGlyphs = "ÄÖÜQÅgjpqy"

    /// Schriften, die sich auf so kleinem Raster bewährt haben.
    public static let recommendedFonts = [
        "Menlo-Bold", "Menlo-Regular", "Monaco", "Courier-Bold",
        "HelveticaNeue-Bold", "Helvetica-Bold", "SFMono-Bold", "Geneva",
    ]

    public var fontName: String
    public var fontSize: Double
    public var rows: Int
    /// 0…1 — Anteil der Deckung, ab dem ein Pixel leuchtet.
    public var threshold: Double
    /// Leerspalten vor dem ersten Zeichen.
    public var leadingPadding: Int

    public init(
        fontName: String = TextRasterizer.defaultFontName,
        fontSize: Double = TextRasterizer.defaultFontSize,
        rows: Int = 11,
        threshold: Double = 0.5,
        leadingPadding: Int = 1
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.rows = rows
        self.threshold = threshold
        self.leadingPadding = leadingPadding
    }

    private func makeFont() -> CTFont {
        // CoreText liefert bei unbekanntem Namen eine Ersatzschrift statt nil,
        // was still zu einem anderen Schriftbild führt. Das ist hier akzeptabel,
        // solange die Vorschau dasselbe rendert wie der Versand.
        CTFontCreateWithName(fontName as CFString, fontSize, nil)
    }

    /// Jedes Pixel ist an oder aus — alle Weichzeichnung abschalten.
    private func configure(_ context: CGContext) {
        context.setShouldAntialias(false)
        context.setAllowsAntialiasing(false)
        context.setShouldSmoothFonts(false)
        context.setAllowsFontSmoothing(false)
        context.setShouldSubpixelPositionFonts(false)
        context.setShouldSubpixelQuantizeFonts(false)
        context.setAllowsFontSubpixelPositioning(false)
        context.setAllowsFontSubpixelQuantization(false)
    }

    private func line(for text: String, font: CTFont) -> CTLine {
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
                NSAttributedString.Key(kCTLigatureAttributeName as String): 0,
            ]
        )
        return CTLineCreateWithAttributedString(attributed)
    }

    /// Wie weit die Extremzeichen tatsächlich über und unter die Grundlinie
    /// leuchten — gemessen an gesetzten Pixeln, nicht an Pfadkonturen. Nur so
    /// stimmt die Rechnung mit dem überein, was hinterher wirklich zu sehen ist.
    private struct InkExtent {
        var above: Int  // Pixelzeilen oberhalb der Grundlinie
        var below: Int  // Pixelzeilen unterhalb
        var height: Int { above + below }
    }

    private func measureExtremeInk() -> InkExtent {
        let canvas = 64
        let baseline = 24
        let font = makeFont()
        let probe = line(for: Self.extremeGlyphs, font: font)
        let width = max(1, Int(ceil(CTLineGetTypographicBounds(probe, nil, nil, nil))) + 2)
        var buffer = [UInt8](repeating: 0, count: width * canvas)
        buffer.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                      data: base, width: width, height: canvas, bitsPerComponent: 8,
                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue
                  )
            else { return }
            configure(context)
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(canvas)))
            context.textPosition = CGPoint(x: 1, y: CGFloat(baseline))
            CTLineDraw(probe, context)
        }

        let cutoff = UInt8(min(max(threshold, 0), 1) * 255)
        var topRow: Int?
        var bottomRow: Int?
        for row in 0..<canvas {
            let start = row * width
            if buffer[start..<(start + width)].contains(where: { $0 > cutoff }) {
                if topRow == nil { topRow = row }
                bottomRow = row
            }
        }
        guard let topRow, let bottomRow else { return InkExtent(above: rows, below: 0) }
        // Pufferzeile 0 ist oben; die Grundlinie liegt bei CG-y = baseline.
        let highest = canvas - 1 - topRow
        let lowest = canvas - 1 - bottomRow
        return InkExtent(above: highest + 1 - baseline, below: baseline - lowest)
    }

    /// Zeilen, die diese Schrift in dieser Größe braucht, damit weder die Punkte
    /// auf Ä/Ö/Ü noch die Unterlängen von g/j/p/q abgeschnitten werden.
    public var requiredRows: Int { measureExtremeInk().height }

    /// Passt die Schrift vollständig auf die Matrix?
    public var fitsRows: Bool { requiredRows <= rows }

    /// Größte Schriftgröße, die noch vollständig auf `rows` Zeilen passt.
    public func largestFittingSize(max upperBound: Double = 24) -> Double {
        var best = 6.0
        var probe = TextRasterizer(fontName: fontName, fontSize: best, rows: rows)
        var size = 6.0
        while size <= upperBound {
            probe.fontSize = size
            if probe.requiredRows <= rows { best = size } else { break }
            size += 1
        }
        return best
    }

    /// Grundlinie in Gerätekoordinaten (von unten gemessen), so gewählt, dass die
    /// Druckfläche der Extremzeichen mittig zwischen erster und letzter LED-Zeile liegt.
    /// Passt sie nicht, wird oben angeschlagen — dort sitzen die Umlautpunkte,
    /// die man auf einem deutschen Namensschild am wenigsten verlieren will.
    private var baselineY: CGFloat {
        let ink = measureExtremeInk()
        let free = rows - ink.height
        guard free >= 0 else {
            // Zu große Schrift: oben anschlagen. Was verloren geht, sind dann die
            // Unterlängen — die Punkte auf Ä, Ö und Ü bleiben erhalten.
            return CGFloat(rows - ink.above)
        }
        return CGFloat(free / 2 + ink.below)
    }

    /// Rendert `text` und liefert die Bitmap in Geräteanordnung.
    public func rasterize(_ text: String) -> ColumnBitmap {
        let trimmed = text
        guard !trimmed.isEmpty else { return ColumnBitmap(rows: rows, byteColumns: 0) }

        let font = makeFont()
        let line = self.line(for: trimmed, font: font)

        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)

        let textWidth = max(1, Int(ceil(advance)))
        let width = textWidth + leadingPadding + 1
        guard width > 0, rows > 0 else { return ColumnBitmap(rows: rows, byteColumns: 0) }

        let bytesPerRow = width
        var buffer = [UInt8](repeating: 0, count: bytesPerRow * rows)

        let drawn: Bool = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                      data: base,
                      width: width,
                      height: rows,
                      bitsPerComponent: 8,
                      bytesPerRow: bytesPerRow,
                      space: CGColorSpaceCreateDeviceGray(),
                      bitmapInfo: CGImageAlphaInfo.none.rawValue
                  )
            else { return false }

            configure(context)

            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(rows)))

            context.textPosition = CGPoint(x: CGFloat(leadingPadding), y: baselineY)
            CTLineDraw(line, context)
            return true
        }
        guard drawn else { return ColumnBitmap(rows: rows, byteColumns: 0) }

        // Der Puffer einer CGBitmapContext liegt zeilenweise von oben nach unten,
        // Zeile 0 ist also die oberste LED-Reihe.
        let cutoff = UInt8(min(max(threshold, 0), 1) * 255)
        var pixels = [[Bool]](repeating: [Bool](repeating: false, count: width), count: rows)
        for y in 0..<rows {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                pixels[y][x] = buffer[rowStart + x] > cutoff
            }
        }

        return ColumnBitmap.from(pixels: trimTrailingBlankColumns(pixels), rows: rows)
    }

    /// Rechts anfallende Leerspalten kosten Speicher auf dem Schild und
    /// erzeugen beim Scrollen eine unnötige Lücke.
    private func trimTrailingBlankColumns(_ pixels: [[Bool]]) -> [[Bool]] {
        guard let width = pixels.first?.count, width > 0 else { return pixels }
        var lastUsed = -1
        for x in stride(from: width - 1, through: 0, by: -1) {
            if pixels.contains(where: { $0[x] }) {
                lastUsed = x
                break
            }
        }
        let keep = lastUsed + 1
        guard keep < width else { return pixels }
        return pixels.map { Array($0.prefix(keep)) }
    }
}
