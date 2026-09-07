import XCTest
@testable import BadgeKit

final class ColumnBitmapTests: XCTestCase {
    func testBitOrderIsMostSignificantFirst() {
        var bitmap = ColumnBitmap(rows: 11, byteColumns: 2)
        bitmap[0, 0] = true    // linkestes Pixel der ersten Byte-Spalte
        bitmap[7, 0] = true    // rechtestes Pixel derselben Byte-Spalte
        bitmap[8, 1] = true    // erstes Pixel der zweiten Byte-Spalte, Zeile 1
        XCTAssertEqual(bitmap.bytes[0], 0b1000_0001)
        XCTAssertEqual(bitmap.bytes[11 + 1], 0b1000_0000)
        XCTAssertTrue(bitmap[0, 0])
        XCTAssertTrue(bitmap[7, 0])
        XCTAssertFalse(bitmap[1, 0])
    }

    func testColumnMajorLayout() {
        var bitmap = ColumnBitmap(rows: 11, byteColumns: 3)
        bitmap[16, 10] = true  // dritte Byte-Spalte, unterste Zeile
        XCTAssertEqual(bitmap.bytes[2 * 11 + 10], 0b1000_0000)
    }

    func testOutOfBoundsIsIgnored() {
        var bitmap = ColumnBitmap(rows: 11, byteColumns: 1)
        bitmap[99, 99] = true
        XCTAssertFalse(bitmap[99, 99])
        XCTAssertTrue(bitmap.bytes.allSatisfy { $0 == 0 })
    }

    func testFromPixelsRoundTrip() {
        var pixels = [[Bool]](repeating: [Bool](repeating: false, count: 9), count: 11)
        pixels[0][0] = true
        pixels[5][8] = true
        let bitmap = ColumnBitmap.from(pixels: pixels, rows: 11)
        XCTAssertEqual(bitmap.byteColumns, 2)
        XCTAssertTrue(bitmap[0, 0])
        XCTAssertTrue(bitmap[8, 5])
    }

    func testTestPatternIsFullyLit() {
        let bitmap = ColumnBitmap.testPattern(rows: 12, byteColumns: 4)
        XCTAssertEqual(bitmap.bytes.count, 48)
        XCTAssertTrue(bitmap.bytes.allSatisfy { $0 == 0xFF })
    }
}

final class TextRasterizerTests: XCTestCase {
    func testEmptyTextProducesNoColumns() {
        let rasterizer = TextRasterizer(rows: 11)
        XCTAssertEqual(rasterizer.rasterize("").byteColumns, 0)
    }

    func testTextProducesLitPixels() {
        let rasterizer = TextRasterizer(rows: 11)
        let bitmap = rasterizer.rasterize("A")
        XCTAssertGreaterThan(bitmap.byteColumns, 0)
        XCTAssertTrue(bitmap.bytes.contains { $0 != 0 }, "Ein 'A' muss Pixel setzen")
        XCTAssertEqual(bitmap.rows, 11)
        XCTAssertEqual(bitmap.bytes.count, bitmap.rows * bitmap.byteColumns)
    }

    func testUmlautsRenderDifferentlyFromBaseLetter() {
        let rasterizer = TextRasterizer(rows: 11)
        XCTAssertNotEqual(rasterizer.rasterize("o").bytes, rasterizer.rasterize("ö").bytes)
        XCTAssertNotEqual(rasterizer.rasterize("ss").bytes, rasterizer.rasterize("ß").bytes)
    }

    func testLongerTextIsWider() {
        let rasterizer = TextRasterizer(rows: 11)
        XCTAssertGreaterThan(
            rasterizer.rasterize("MMMMMMMM").pixelWidth,
            rasterizer.rasterize("MM").pixelWidth
        )
    }

    func testTwelveRowsFillTwelveBytesPerColumn() {
        let bitmap = TextRasterizer(rows: 12).rasterize("Hallo")
        XCTAssertEqual(bitmap.rows, 12)
        XCTAssertEqual(bitmap.bytes.count % 12, 0)
    }

    func testRasterizationIsDeterministic() {
        let rasterizer = TextRasterizer(rows: 11)
        XCTAssertEqual(rasterizer.rasterize("Lukas Köhl").bytes, rasterizer.rasterize("Lukas Köhl").bytes)
    }
}

final class BadgeJobTests: XCTestCase {
    func testDisabledMessagesAreLeftOut() throws {
        var document = BadgeDocument()
        document.messages[0] = BadgeMessage(id: 0, text: "Hallo", isEnabled: true)
        document.messages[1] = BadgeMessage(id: 1, text: "Versteckt", isEnabled: false)
        let plan = try BadgeJob.build(document: document)
        XCTAssertNotNil(plan.slots[0].bitmap)
        XCTAssertNil(plan.slots[1].bitmap)
    }

    func testWhitespaceOnlyMessageIsTreatedAsEmpty() throws {
        var document = BadgeDocument()
        document.messages[0] = BadgeMessage(id: 0, text: "   ", isEnabled: true)
        XCTAssertNil(try BadgeJob.build(document: document).slots[0].bitmap)
    }

    func testFillRatioGrowsWithText() throws {
        var short = BadgeDocument()
        short.messages[0] = BadgeMessage(id: 0, text: "Hi", isEnabled: true)
        var long = BadgeDocument()
        long.messages[0] = BadgeMessage(id: 0, text: String(repeating: "Hallo Welt ", count: 10), isEnabled: true)
        XCTAssertLessThan(
            try BadgeJob.build(document: short).fillRatio,
            try BadgeJob.build(document: long).fillRatio
        )
    }

    func testTestPatternPayloadIsValid() throws {
        for rows in BadgeRowCount.allCases {
            let payload = try BadgeJob.testPatternPayload(rows: rows)
            XCTAssertEqual(Array(payload.prefix(5)), [0x77, 0x61, 0x6E, 0x67, 0x00])
            XCTAssertEqual(payload[8], 0x34, "Testmuster: Speed 4, Modus 'stehend'")
            XCTAssertTrue(payload.dropFirst(64).prefix(rows.rawValue).allSatisfy { $0 == 0xFF })
        }
    }
}

/// Auf einem deutschen Namensschild dürfen die Punkte auf Ä, Ö und Ü nicht fehlen —
/// sie sitzen ganz oben und fallen bei naiver Grundlinienrechnung als Erstes weg.
final class UmlautClippingTests: XCTestCase {
    private func topRowIsLit(_ text: String, size: Double, rows: Int = 11) -> Bool {
        let bitmap = TextRasterizer(fontSize: size, rows: rows).rasterize(text)
        return (0..<bitmap.pixelWidth).contains { bitmap[$0, 0] }
    }

    private func bottomRowIsLit(_ text: String, size: Double, rows: Int = 11) -> Bool {
        let bitmap = TextRasterizer(fontSize: size, rows: rows).rasterize(text)
        return (0..<bitmap.pixelWidth).contains { bitmap[$0, rows - 1] }
    }

    func testCapitalUmlautsKeepTheirDots() {
        let size = TextRasterizer.defaultFontSize
        XCTAssertTrue(topRowIsLit("ÄÖÜ", size: size), "Die Umlautpunkte auf Großbuchstaben fehlen")
        XCTAssertFalse(topRowIsLit("AOU", size: size), "Ohne Umlaut darf die oberste Zeile leer bleiben")
    }

    func testDescendersSurvive() {
        XCTAssertTrue(bottomRowIsLit("gjpqy", size: TextRasterizer.defaultFontSize))
    }

    func testDefaultSizeFitsElevenRows() {
        let rasterizer = TextRasterizer(rows: 11)
        XCTAssertTrue(rasterizer.fitsRows, "Vorgabegröße braucht \(rasterizer.requiredRows) Zeilen")
    }

    func testOversizedFontKeepsUmlautsAndSacrificesDescenders() {
        // 14 pt passen nicht auf elf Zeilen. Dann müssen die Punkte gewinnen.
        let rasterizer = TextRasterizer(fontSize: 14, rows: 11)
        XCTAssertFalse(rasterizer.fitsRows)
        XCTAssertTrue(topRowIsLit("Ä", size: 14))
    }

    func testLargestFittingSizeActuallyFits() {
        for rows in [11, 12] {
            for font in TextRasterizer.recommendedFonts {
                let probe = TextRasterizer(fontName: font, rows: rows)
                let size = probe.largestFittingSize()
                XCTAssertTrue(
                    TextRasterizer(fontName: font, fontSize: size, rows: rows).fitsRows,
                    "\(font) @ \(size) pt passt nicht auf \(rows) Zeilen"
                )
            }
        }
    }

    func testBaselineIsStableAcrossMessages() {
        // Ein Text ohne Unterlängen darf nicht anders sitzen als einer mit.
        let rasterizer = TextRasterizer(rows: 11)
        let withDescender = rasterizer.rasterize("Hg")
        let without = rasterizer.rasterize("H")
        let topOf: (ColumnBitmap) -> Int? = { bitmap in
            (0..<bitmap.rows).first { row in (0..<bitmap.pixelWidth).contains { bitmap[$0, row] } }
        }
        XCTAssertEqual(topOf(withDescender), topOf(without))
    }
}
