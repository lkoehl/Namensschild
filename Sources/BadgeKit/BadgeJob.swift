import Foundation

/// Bindeglied zwischen Dokument und Gerät: rastert die Texte, baut den Puffer
/// und rechnet aus, wie viel Speicher das Schild dabei belegt.
public enum BadgeJob {
    public struct Plan: Sendable {
        public let payload: Data
        public let slots: [BadgeProtocol.Slot]
        public let usedColumns: Int
        public let columnBudget: Int

        public var fillRatio: Double {
            columnBudget > 0 ? Double(usedColumns) / Double(columnBudget) : 0
        }
    }

    /// Rastert alle Nachrichten des Dokuments — auch die abgeschalteten,
    /// damit die Vorschau sofort etwas zeigt, wenn man sie anhakt.
    public static func rasterizeAll(_ document: BadgeDocument) -> [ColumnBitmap] {
        let rasterizer = TextRasterizer(
            fontName: document.fontName,
            fontSize: document.fontSize,
            rows: document.rowCount.rawValue
        )
        return document.messages.map { rasterizer.rasterize($0.text) }
    }

    public static func build(document: BadgeDocument, date: Date = Date()) throws -> Plan {
        let bitmaps = rasterizeAll(document)
        let slots = document.messages.enumerated().map { index, message in
            BadgeProtocol.Slot(
                settings: message,
                bitmap: message.carriesContent ? bitmaps[index] : nil
            )
        }
        let rows = document.rowCount.rawValue
        let payload = try BadgeProtocol.encode(
            slots: slots,
            brightness: document.brightness,
            rows: rows,
            date: date
        )
        return Plan(
            payload: payload,
            slots: slots,
            usedColumns: slots.reduce(0) { $0 + ($1.bitmap?.byteColumns ?? 0) },
            columnBudget: BadgeProtocol.columnBudget(rows: rows)
        )
    }

    /// Vollflächiges Muster auf Platz 1 — damit lässt sich die Zeilenzahl abzählen.
    public static func testPatternPayload(rows: BadgeRowCount, brightness: BadgeBrightness = .p100) throws -> Data {
        let settings = BadgeMessage(id: 0, effect: .still, speed: 4, isEnabled: true)
        let slot = BadgeProtocol.Slot(
            settings: settings,
            bitmap: ColumnBitmap.testPattern(rows: rows.rawValue)
        )
        return try BadgeProtocol.encode(slots: [slot], brightness: brightness, rows: rows.rawValue)
    }
}
