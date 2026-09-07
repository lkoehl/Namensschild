// Erzeugt das App-Symbol: der Buchstabe N aus leuchtenden LED-Punkten.
// Aufruf: swift Tools/make-icon.swift <Zielordner>
import AppKit
import CoreGraphics
import CoreText
import Foundation

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let dotColor = CGColor(red: 0.36, green: 0.72, blue: 1.0, alpha: 1)

// MARK: - Form

/// Superellipse statt Kreisecken — das ist die Silhouette, die macOS-Symbole haben.
func squircle(in rect: CGRect, exponent n: CGFloat = 6) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let steps = 720
    for step in 0...steps {
        let t = CGFloat(step) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = cy + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

/// Eine LED: weicher Hof, satter Körper, heller Kern.
func drawLED(_ context: CGContext, center: CGPoint, radius: CGFloat, bloom: CGFloat) {
    let space = CGColorSpaceCreateDeviceRGB()
    let parts = dotColor.components ?? [0, 0, 0, 1]
    if bloom > 1 {
        let halo = CGGradient(colorsSpace: space, colors: [
            CGColor(red: parts[0], green: parts[1], blue: parts[2], alpha: 0.55),
            CGColor(red: parts[0], green: parts[1], blue: parts[2], alpha: 0.0),
        ] as CFArray, locations: [0, 1])!
        context.drawRadialGradient(halo, startCenter: center, startRadius: radius * 0.5,
                                   endCenter: center, endRadius: radius * bloom, options: [])
    }
    context.setFillColor(dotColor)
    context.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2))
    context.setFillColor(CGColor(red: 0.71, green: 0.90, blue: 1, alpha: 0.85))
    context.fillEllipse(in: CGRect(x: center.x - radius * 0.42, y: center.y - radius * 0.42,
                                   width: radius * 0.84, height: radius * 0.84))
}

/// Das N ist von Hand gesetzt statt aus einer Schrift gerastert. Bei neun
/// Punktzeilen entscheidet jedes einzelne Pixel über die Lesbarkeit, und die
/// Diagonale einer echten Schrift wird auf diesem Raster zu dünn.
enum LetterN {
    /// 7 × 9 — für alle Größen ab 64 px.
    static let large = [
        "X.....X",
        "XX....X",
        "XX....X",
        "X.X...X",
        "X..X..X",
        "X...X.X",
        "X....XX",
        "X....XX",
        "X.....X",
    ]

    /// 5 × 7 — in der Menüleiste zählt jeder Punkt doppelt.
    static let small = [
        "X...X",
        "XX..X",
        "XX..X",
        "X.X.X",
        "X..XX",
        "X..XX",
        "X...X",
    ]

    static func grid(compact: Bool) -> [[Bool]] {
        (compact ? small : large).map { row in row.map { $0 == "X" } }
    }
}

// MARK: - Zeichnen

func drawIcon(size: Int) -> CGImage? {
    let side = CGFloat(size)
    guard let context = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    // Grundfläche. Der Beschnitt bleibt bestehen, damit kein Leuchten über den Rand tritt.
    let body = CGRect(x: side * 0.035, y: side * 0.035, width: side * 0.93, height: side * 0.93)
    context.addPath(squircle(in: body))
    context.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [CGColor(red: 0.13, green: 0.16, blue: 0.24, alpha: 1),
                 CGColor(red: 0.04, green: 0.05, blue: 0.09, alpha: 1)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(background, start: CGPoint(x: 0, y: side), end: CGPoint(x: 0, y: 0), options: [])

    // Kleine Symbole bekommen ein gröberes Raster und weniger Hof, sonst
    // verschmiert der Buchstabe in der Menüleiste zu einem blauen Fleck.
    let compact = size <= 32
    let bloom: CGFloat = compact ? 1.0 : (size <= 64 ? 1.8 : 2.6)
    let grid = LetterN.grid(compact: compact)
    let rows = grid.count
    let columns = grid[0].count

    var cell = side * 0.60 / CGFloat(rows)

    // Unter etwa drei Pixeln pro Punkt wird aus jedem Kreis ein grauer Fleck.
    // Dann lieber auf ganze Pixel rasten und Quadrate setzen — das bleibt scharf.
    let blocky = cell < 3
    if blocky { cell = max(1, (side * 0.60 / CGFloat(rows)).rounded(.down)) }

    let originX = (side / 2 - cell * CGFloat(columns) / 2).rounded()
    let originY = (side / 2 + cell * CGFloat(rows) / 2).rounded()
    for y in 0..<rows {
        for x in 0..<columns where grid[y][x] {
            if blocky {
                context.setFillColor(dotColor)
                context.fill(CGRect(x: originX + CGFloat(x) * cell,
                                    y: originY - CGFloat(y + 1) * cell,
                                    width: cell, height: cell))
            } else {
                drawLED(context,
                        center: CGPoint(x: originX + (CGFloat(x) + 0.5) * cell,
                                        y: originY - (CGFloat(y) + 0.5) * cell),
                        radius: cell * 0.36,
                        bloom: bloom)
            }
        }
    }
    return context.makeImage()
}

// MARK: - Ausgabe

let iconset = URL(fileURLWithPath: outputDirectory).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for (size, name) in [(16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"),
                     (64, "icon_32x32@2x"), (128, "icon_128x128"), (256, "icon_128x128@2x"),
                     (256, "icon_256x256"), (512, "icon_256x256@2x"), (512, "icon_512x512"),
                     (1024, "icon_512x512@2x")] {
    guard let image = drawIcon(size: size) else { continue }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: size, height: size)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}
print("Iconset geschrieben: \(iconset.path)")
