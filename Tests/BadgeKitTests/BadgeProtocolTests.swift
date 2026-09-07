import XCTest
@testable import BadgeKit

final class BadgeProtocolTests: XCTestCase {
    private func bitmap(rows: Int = 11, columns: Int) -> ColumnBitmap {
        ColumnBitmap(rows: rows, byteColumns: columns, bytes: [UInt8](repeating: 0xAA, count: rows * columns))
    }

    private func slot(
        index: Int,
        columns: Int,
        effect: BadgeEffect = .scrollLeft,
        speed: Int = 4,
        blink: Bool = false,
        border: Bool = false
    ) -> BadgeProtocol.Slot {
        BadgeProtocol.Slot(
            settings: BadgeMessage(id: index, text: "x", effect: effect, speed: speed,
                                   blink: blink, border: border, isEnabled: true),
            bitmap: columns > 0 ? bitmap(columns: columns) : nil
        )
    }

    private var referenceDate: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 9; components.day = 7
        components.hour = 14; components.minute = 5; components.second = 33
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testHeaderMagicAndSize() throws {
        let data = try BadgeProtocol.encode(slots: [slot(index: 0, columns: 1)], brightness: .p100, rows: 11)
        XCTAssertEqual(Array(data.prefix(5)), [0x77, 0x61, 0x6E, 0x67, 0x00])
        XCTAssertEqual(data.count % BadgeProtocol.blockSize, 0)
    }

    func testBrightnessByte() throws {
        let expected: [BadgeBrightness: UInt8] = [.p100: 0x00, .p75: 0x10, .p50: 0x20, .p25: 0x40]
        for (level, byte) in expected {
            let data = try BadgeProtocol.encode(slots: [slot(index: 0, columns: 1)], brightness: level, rows: 11)
            XCTAssertEqual(data[5], byte, "Helligkeit \(level.rawValue) %")
        }
    }

    func testBlinkAndBorderBitmasks() throws {
        let slots = (0..<8).map { index in
            slot(index: index, columns: 1, blink: index % 2 == 0, border: index >= 6)
        }
        let data = try BadgeProtocol.encode(slots: slots, brightness: .p100, rows: 11)
        XCTAssertEqual(data[6], 0b0101_0101)
        XCTAssertEqual(data[7], 0b1100_0000)
    }

    func testSpeedAndModeByte() throws {
        // Speed 1 → Nibble 0, Speed 8 → Nibble 7. Mode steht im unteren Nibble.
        let slots = [
            slot(index: 0, columns: 1, effect: .laser, speed: 8),
            slot(index: 1, columns: 1, effect: .scrollLeft, speed: 1),
            slot(index: 2, columns: 1, effect: .curtain, speed: 4),
        ]
        let data = try BadgeProtocol.encode(slots: slots, brightness: .p100, rows: 11)
        XCTAssertEqual(data[8], 0x78)   // (8-1)<<4 | 8
        XCTAssertEqual(data[9], 0x00)   // (1-1)<<4 | 0
        XCTAssertEqual(data[10], 0x37)  // (4-1)<<4 | 7
        XCTAssertEqual(data[11], 0x40, "Unbenutzte Plätze behalten den Werkswert")
    }

    func testSpeedIsClamped() throws {
        let slots = [slot(index: 0, columns: 1, speed: 99), slot(index: 1, columns: 1, speed: -3)]
        let data = try BadgeProtocol.encode(slots: slots, brightness: .p100, rows: 11)
        XCTAssertEqual(data[8], 0x70)
        XCTAssertEqual(data[9], 0x00)
    }

    func testLengthsAreBigEndian() throws {
        let slots = [slot(index: 0, columns: 300), slot(index: 1, columns: 5)]
        let data = try BadgeProtocol.encode(slots: slots, brightness: .p100, rows: 11)
        XCTAssertEqual(data[16], 0x01)
        XCTAssertEqual(data[17], 0x2C)  // 300 = 0x012C
        XCTAssertEqual(data[18], 0x00)
        XCTAssertEqual(data[19], 0x05)
        for index in 2..<8 {
            XCTAssertEqual(data[16 + 2 * index], 0)
            XCTAssertEqual(data[17 + 2 * index], 0)
        }
    }

    func testDisabledSlotKeepsItsPositionInTheLengthTable() throws {
        let slots = [
            slot(index: 0, columns: 3),
            BadgeProtocol.Slot(settings: BadgeMessage(id: 1), bitmap: nil),
            slot(index: 2, columns: 4),
        ]
        let data = try BadgeProtocol.encode(slots: slots, brightness: .p100, rows: 11)
        XCTAssertEqual(data[17], 3)
        XCTAssertEqual(data[19], 0, "Leerer Platz muss Länge 0 melden")
        XCTAssertEqual(data[21], 4)
        // Nutzdaten folgen lückenlos: 3 + 4 Byte-Spalten à 11 Bytes = 141 Bytes,
        // aufgefüllt auf das nächste Vielfache von 64.
        XCTAssertEqual(BadgeProtocol.headerSize + 7 * 11, 141)
        XCTAssertEqual(data.count, 192)
    }

    func testTimestamp() throws {
        let data = try BadgeProtocol.encode(
            slots: [slot(index: 0, columns: 1)], brightness: .p100, rows: 11, date: referenceDate
        )
        XCTAssertEqual(Array(data[38..<44]), [26, 9, 7, 14, 5, 33])
    }

    func testPayloadFollowsHeader() throws {
        let data = try BadgeProtocol.encode(slots: [slot(index: 0, columns: 2)], brightness: .p100, rows: 11)
        XCTAssertEqual(Array(data[64..<(64 + 22)]), [UInt8](repeating: 0xAA, count: 22))
    }

    func testTwelveRowGeometry() throws {
        let data = try BadgeProtocol.encode(
            slots: [BadgeProtocol.Slot(settings: BadgeMessage(id: 0, isEnabled: true),
                                       bitmap: bitmap(rows: 12, columns: 2))],
            brightness: .p100, rows: 12
        )
        XCTAssertEqual(data[17], 2)
        XCTAssertEqual(Array(data[64..<(64 + 24)]), [UInt8](repeating: 0xAA, count: 24))
    }

    func testRowMismatchIsRejected() {
        XCTAssertThrowsError(
            try BadgeProtocol.encode(
                slots: [BadgeProtocol.Slot(settings: BadgeMessage(id: 0), bitmap: bitmap(rows: 12, columns: 1))],
                brightness: .p100, rows: 11
            )
        ) { error in
            XCTAssertEqual(error as? BadgeProtocolError, .rowMismatch(expected: 11, found: 12))
        }
    }

    func testOversizedPayloadIsRejected() {
        let columns = BadgeProtocol.columnBudget(rows: 11) + 1
        XCTAssertThrowsError(
            try BadgeProtocol.encode(slots: [slot(index: 0, columns: columns)], brightness: .p100, rows: 11)
        ) { error in
            guard case .payloadTooLarge = (error as? BadgeProtocolError) else {
                return XCTFail("Falscher Fehler: \(error)")
            }
        }
    }

    func testBudgetEdgeIsAccepted() throws {
        let columns = BadgeProtocol.columnBudget(rows: 11)
        let data = try BadgeProtocol.encode(slots: [slot(index: 0, columns: columns)], brightness: .p100, rows: 11)
        XCTAssertLessThanOrEqual(data.count, BadgeProtocol.maxPayloadSize)
    }

    func testTooManySlots() {
        let slots = (0..<9).map { slot(index: $0, columns: 1) }
        XCTAssertThrowsError(try BadgeProtocol.encode(slots: slots, brightness: .p100, rows: 11)) { error in
            XCTAssertEqual(error as? BadgeProtocolError, .tooManyMessages(9))
        }
    }

    func testReportSplitting() throws {
        let data = try BadgeProtocol.encode(slots: [slot(index: 0, columns: 10)], brightness: .p100, rows: 11)
        let reports = BadgeProtocol.reports(from: data)
        XCTAssertEqual(reports.count, data.count / 64)
        XCTAssertTrue(reports.allSatisfy { $0.count == 64 })
        XCTAssertEqual(Data(reports.joined()), data)
    }
}
