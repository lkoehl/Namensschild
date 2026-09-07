import Foundation

public enum BadgeProtocolError: Error, LocalizedError, Equatable {
    case payloadTooLarge(bytes: Int, limit: Int)
    case rowMismatch(expected: Int, found: Int)
    case tooManyMessages(Int)

    public var errorDescription: String? {
        switch self {
        case let .payloadTooLarge(bytes, limit):
            return "Die Nachrichten belegen \(bytes) Bytes, das Schild fasst nur \(limit). Kürze den Text oder verkleinere die Schrift."
        case let .rowMismatch(expected, found):
            return "Bitmap hat \(found) Zeilen, erwartet werden \(expected)."
        case let .tooManyMessages(count):
            return "\(count) Nachrichten übergeben, das Schild kennt nur \(BadgeDocument.slotCount) Plätze."
        }
    }
}

/// Baut den Bytestrom, den das Schild über USB-HID entgegennimmt.
///
/// Aufbau: 64 Byte Header, danach die Bitmaps der Nachrichten in Slot-Reihenfolge,
/// zum Schluss auf ein Vielfaches der Blockgröße mit Nullen aufgefüllt.
public enum BadgeProtocol {
    public static let magic: [UInt8] = [0x77, 0x61, 0x6E, 0x67, 0x00]  // "wang\0"
    public static let headerSize = 64
    public static let blockSize = 64
    public static let maxPayloadSize = 8192

    /// Nutzbare Byte-Spalten für alle acht Nachrichten zusammen.
    public static func columnBudget(rows: Int) -> Int {
        (maxPayloadSize - headerSize) / rows
    }

    /// Ein Nachrichtenplatz: Einstellungen plus die dazugehörige Bitmap.
    /// Ist `bitmap` nil, bleibt der Platz leer (Länge 0).
    public struct Slot: Sendable {
        public var settings: BadgeMessage
        public var bitmap: ColumnBitmap?

        public init(settings: BadgeMessage, bitmap: ColumnBitmap?) {
            self.settings = settings
            self.bitmap = bitmap
        }
    }

    public static func encode(
        slots: [Slot],
        brightness: BadgeBrightness,
        rows: Int,
        date: Date = Date(),
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) throws -> Data {
        guard slots.count <= BadgeDocument.slotCount else {
            throw BadgeProtocolError.tooManyMessages(slots.count)
        }
        for slot in slots {
            if let bitmap = slot.bitmap, bitmap.rows != rows {
                throw BadgeProtocolError.rowMismatch(expected: rows, found: bitmap.rows)
            }
        }

        var header = [UInt8](repeating: 0, count: headerSize)
        header.replaceSubrange(0..<magic.count, with: magic)
        header[5] = brightness.headerByte

        for (index, slot) in slots.enumerated() {
            if slot.settings.blink  { header[6] |= 1 << UInt8(index) }
            if slot.settings.border { header[7] |= 1 << UInt8(index) }
        }

        // Offsets 8..15: je Nachricht (speed-1) << 4 | mode.
        // Ungenutzte Plätze behalten den Werkswert 0x40 (Speed 5, Scroll links).
        for index in 0..<BadgeDocument.slotCount {
            if index < slots.count {
                let settings = slots[index].settings
                header[8 + index] = UInt8((settings.clampedSpeed - 1) << 4) | settings.effect.rawValue
            } else {
                header[8 + index] = 0x40
            }
        }

        // Offsets 16..31: acht Längen als uint16 big-endian, in Byte-Spalten.
        for index in 0..<BadgeDocument.slotCount {
            let length = index < slots.count ? (slots[index].bitmap?.byteColumns ?? 0) : 0
            header[16 + 2 * index] = UInt8((length >> 8) & 0xFF)
            header[17 + 2 * index] = UInt8(length & 0xFF)
        }

        // Offsets 38..43: Zeitstempel. Das Schild zeigt ihn nicht an, erwartet ihn aber.
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        header[38] = UInt8((parts.year ?? 2000) % 100)
        header[39] = UInt8(parts.month ?? 1)
        header[40] = UInt8(parts.day ?? 1)
        header[41] = UInt8(parts.hour ?? 0)
        header[42] = UInt8(parts.minute ?? 0)
        header[43] = UInt8(parts.second ?? 0)

        var payload = Data(header)
        for slot in slots {
            if let bitmap = slot.bitmap {
                payload.append(contentsOf: bitmap.bytes)
            }
        }

        guard payload.count <= maxPayloadSize else {
            throw BadgeProtocolError.payloadTooLarge(bytes: payload.count, limit: maxPayloadSize)
        }

        let remainder = payload.count % blockSize
        if remainder != 0 {
            payload.append(contentsOf: [UInt8](repeating: 0, count: blockSize - remainder))
        }
        return payload
    }

    /// Zerlegt den Puffer in die 64-Byte-Reports, die einzeln gesendet werden.
    public static func reports(from payload: Data) -> [Data] {
        stride(from: 0, to: payload.count, by: blockSize).map { start in
            payload.subdata(in: start..<min(start + blockSize, payload.count))
        }
    }
}
