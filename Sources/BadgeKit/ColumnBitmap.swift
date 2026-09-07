import Foundation

/// Eine monochrome Bitmap in genau der Anordnung, die das Schild erwartet:
/// spaltenweise, je Byte-Spalte `rows` Bytes, ein Byte pro LED-Zeile,
/// MSB = linkestes der acht Pixel.
public struct ColumnBitmap: Equatable, Sendable {
    public let rows: Int
    public let byteColumns: Int
    public private(set) var bytes: [UInt8]

    public init(rows: Int, byteColumns: Int) {
        self.rows = rows
        self.byteColumns = byteColumns
        self.bytes = [UInt8](repeating: 0, count: rows * byteColumns)
    }

    public init(rows: Int, byteColumns: Int, bytes: [UInt8]) {
        precondition(bytes.count == rows * byteColumns, "Bytezahl passt nicht zur Geometrie")
        self.rows = rows
        self.byteColumns = byteColumns
        self.bytes = bytes
    }

    /// Breite in Pixeln (immer ein Vielfaches von 8).
    public var pixelWidth: Int { byteColumns * 8 }

    public subscript(x: Int, y: Int) -> Bool {
        get {
            guard x >= 0, y >= 0, x < pixelWidth, y < rows else { return false }
            let index = (x / 8) * rows + y
            return bytes[index] & (0x80 >> UInt8(x % 8)) != 0
        }
        set {
            guard x >= 0, y >= 0, x < pixelWidth, y < rows else { return }
            let index = (x / 8) * rows + y
            let mask: UInt8 = 0x80 >> UInt8(x % 8)
            if newValue { bytes[index] |= mask } else { bytes[index] &= ~mask }
        }
    }

    /// Baut eine Bitmap aus einem Pixelraster (`pixels[y][x]`).
    public static func from(pixels: [[Bool]], rows: Int) -> ColumnBitmap {
        let width = pixels.first?.count ?? 0
        let byteColumns = (width + 7) / 8
        var bitmap = ColumnBitmap(rows: rows, byteColumns: byteColumns)
        for y in 0..<min(rows, pixels.count) {
            for x in 0..<width where pixels[y][x] {
                bitmap[x, y] = true
            }
        }
        return bitmap
    }

    /// Vollflächiges Testmuster über `byteColumns` Byte-Spalten.
    public static func testPattern(rows: Int, byteColumns: Int = 6) -> ColumnBitmap {
        ColumnBitmap(
            rows: rows,
            byteColumns: byteColumns,
            bytes: [UInt8](repeating: 0xFF, count: rows * byteColumns)
        )
    }

    /// Darstellung als ASCII-Grafik — für Terminal-Vorschau und Tests.
    public func asciiArt(on: Character = "#", off: Character = ".") -> String {
        (0..<rows).map { y in
            String((0..<pixelWidth).map { x in self[x, y] ? on : off })
        }
        .joined(separator: "\n")
    }
}
