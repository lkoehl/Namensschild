import Foundation

/// Ein kleines Symbol, Punkt für Punkt von Hand gesetzt.
///
/// Auf elf Zeilen entscheidet jedes einzelne Pixel über die Erkennbarkeit —
/// eine skalierte Vektorgrafik oder ein Emoji aus einer Systemschrift wird
/// hier unweigerlich zu Matsch. Deshalb sind alle Symbole neun Zeilen hoch
/// gezeichnet und werden auf der Matrix senkrecht zentriert.
public struct PixelIcon: Sendable, Identifiable, Hashable {
    /// Kürzel, mit dem das Symbol im Text steht: `:herz:`
    public let name: String
    public let germanName: String
    public let pattern: [String]

    public var id: String { name }
    public var width: Int { pattern.first?.count ?? 0 }
    public var height: Int { pattern.count }
    /// So, wie es im Text geschrieben wird.
    public var token: String { ":\(name):" }

    /// Punktraster des Symbols, senkrecht zentriert auf `rows` Zeilen.
    public func pixels(rows: Int) -> [[Bool]] {
        var grid = [[Bool]](repeating: [Bool](repeating: false, count: width), count: rows)
        let top = max(0, (rows - height) / 2)
        for y in 0..<min(height, rows - top) {
            let line = Array(pattern[y])
            for x in 0..<width where line[x] != "." {
                grid[top + y][x] = true
            }
        }
        return grid
    }
}

public enum PixelIcons {
    public static subscript(name: String) -> PixelIcon? {
        all.first { $0.name == name.lowercased() }
    }

    public static let all: [PixelIcon] = [
        PixelIcon(name: "herz", germanName: "Herz", pattern: [
            ".XX...XX.",
            "XXXXXXXXX",
            "XXXXXXXXX",
            "XXXXXXXXX",
            ".XXXXXXX.",
            ".XXXXXXX.",
            "..XXXXX..",
            "...XXX...",
            "....X....",
        ]),
        PixelIcon(name: "stern", germanName: "Stern", pattern: [
            "....X....",
            "....X....",
            "...XXX...",
            "XXXXXXXXX",
            ".XXXXXXX.",
            "..XXXXX..",
            "..XX.XX..",
            ".XX...XX.",
            ".X.....X.",
        ]),
        PixelIcon(name: "haken", germanName: "Haken", pattern: [
            ".........",
            ".......XX",
            "......XX.",
            ".....XX..",
            "X...XX...",
            "XX.XX....",
            ".XXXX....",
            "..XX.....",
            ".........",
        ]),
        PixelIcon(name: "kreuz", germanName: "Kreuz", pattern: [
            ".........",
            ".XX...XX.",
            ".XXX.XXX.",
            "..XXXXX..",
            "...XXX...",
            "..XXXXX..",
            ".XXX.XXX.",
            ".XX...XX.",
            ".........",
        ]),
        PixelIcon(name: "rechts", germanName: "Pfeil nach rechts", pattern: [
            "....X....",
            "....XX...",
            "....XXX..",
            "XXXXXXXX.",
            "XXXXXXXXX",
            "XXXXXXXX.",
            "....XXX..",
            "....XX...",
            "....X....",
        ]),
        PixelIcon(name: "links", germanName: "Pfeil nach links", pattern: [
            "....X....",
            "...XX....",
            "..XXX....",
            ".XXXXXXXX",
            "XXXXXXXXX",
            ".XXXXXXXX",
            "..XXX....",
            "...XX....",
            "....X....",
        ]),
        PixelIcon(name: "wlan", germanName: "WLAN", pattern: [
            ".........",
            "..XXXXX..",
            ".X.....X.",
            "X.......X",
            "...XXX...",
            "..X...X..",
            ".........",
            "....X....",
            ".........",
        ]),
        PixelIcon(name: "kaffee", germanName: "Kaffee", pattern: [
            "..X.X.X..",
            "..X.X.X..",
            ".........",
            "XXXXXXX..",
            "X.....X.X",
            "X.....XX.",
            "X.....X.X",
            "X.....X..",
            ".XXXXX...",
        ]),
        PixelIcon(name: "achtung", germanName: "Achtung", pattern: [
            "....X....",
            "...XXX...",
            "...X.X...",
            "..XX.XX..",
            "..XX.XX..",
            ".XXX.XXX.",
            ".XXXXXXX.",
            "XXXX.XXXX",
            "XXXXXXXXX",
        ]),
        PixelIcon(name: "smiley", germanName: "Smiley", pattern: [
            "..XXXXX..",
            ".X.....X.",
            "X.X...X.X",
            "X.......X",
            "X.X...X.X",
            "X..XXX..X",
            ".X.....X.",
            "..XXXXX..",
            ".........",
        ]),
        PixelIcon(name: "note", germanName: "Note", pattern: [
            "....XXXX.",
            "....X..XX",
            "....X...X",
            "....X..XX",
            "....XXXX.",
            "....X....",
            ".XXXX....",
            "XXXXX....",
            ".XXX.....",
        ]),
        PixelIcon(name: "blitz", germanName: "Blitz", pattern: [
            ".....XXX.",
            "....XXX..",
            "...XXX...",
            "..XXXXXX.",
            ".XXXXXX..",
            "....XXX..",
            "...XXX...",
            "..XXX....",
            ".XXX.....",
        ]),
    ]
}
