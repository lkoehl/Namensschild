import XCTest
@testable import BadgeKit

final class PixelIconTests: XCTestCase {
    func testCatalogIsWellFormed() {
        XCTAssertFalse(PixelIcons.all.isEmpty)
        for icon in PixelIcons.all {
            XCTAssertEqual(icon.name, icon.name.lowercased(), "\(icon.name): Kürzel müssen klein sein")
            XCTAssertFalse(icon.name.contains(":"), "\(icon.name): Doppelpunkt im Kürzel")
            XCTAssertEqual(icon.height, 9, "\(icon.name) ist \(icon.height) statt 9 Zeilen hoch")
            let widths = Set(icon.pattern.map(\.count))
            XCTAssertEqual(widths.count, 1, "\(icon.name) hat unterschiedlich lange Zeilen: \(widths)")
            XCTAssertTrue(icon.pattern.contains { $0.contains("X") }, "\(icon.name) ist leer")
        }
        XCTAssertEqual(Set(PixelIcons.all.map(\.name)).count, PixelIcons.all.count, "Doppeltes Kürzel")
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(PixelIcons["HERZ"]?.name, "herz")
        XCTAssertNil(PixelIcons["gibtesnicht"])
    }

    func testIconIsVerticallyCentred() {
        let icon = PixelIcons["herz"]!
        let pixels = icon.pixels(rows: 11)
        XCTAssertEqual(pixels.count, 11)
        XCTAssertFalse(pixels[0].contains(true), "Oberste Zeile bleibt als Rand frei")
        XCTAssertFalse(pixels[10].contains(true), "Unterste Zeile bleibt als Rand frei")
        XCTAssertTrue(pixels[1].contains(true))
    }

    func testIconFitsTwelveRowsToo() {
        XCTAssertEqual(PixelIcons["stern"]!.pixels(rows: 12).count, 12)
    }
}

final class IconTokenTests: XCTestCase {
    private func describe(_ text: String) -> [String] {
        TextRasterizer.split(text).map { segment in
            switch segment {
            case let .text(value): return "T(\(value))"
            case let .icon(icon):  return "I(\(icon.name))"
            }
        }
    }

    func testPlainTextStaysOneSegment() {
        XCTAssertEqual(describe("Lukas Köhl"), ["T(Lukas Köhl)"])
    }

    func testIconIsRecognised() {
        XCTAssertEqual(describe("Ich :herz: Kaffee"), ["T(Ich )", "I(herz)", "T( Kaffee)"])
    }

    func testIconAtBothEnds() {
        XCTAssertEqual(describe(":stern:Gold:stern:"), ["I(stern)", "T(Gold)", "I(stern)"])
    }

    func testDoubleColonIsALiteralColon() {
        XCTAssertEqual(describe("12::30 Uhr"), ["T(12:30 Uhr)"])
    }

    func testUnknownTokenSurvivesVisibly() {
        // Lieber der sichtbare Tippfehler auf dem Schild als stillschweigend fehlender Text.
        XCTAssertEqual(describe("Hallo :gibtesnicht: Welt"), ["T(Hallo :gibtesnicht: Welt)"])
    }

    func testUnbalancedColonIsHarmless() {
        XCTAssertEqual(describe("Preis: 5 Euro"), ["T(Preis: 5 Euro)"])
    }

    func testIconMakesTheBitmapWider() {
        let rasterizer = TextRasterizer(rows: 11)
        let plain = rasterizer.rasterize("Hallo")
        let withIcon = rasterizer.rasterize("Hallo :herz:")
        XCTAssertGreaterThan(withIcon.pixelWidth, plain.pixelWidth)
    }

    func testIconOnlyMessageRenders() {
        let bitmap = TextRasterizer(rows: 11).rasterize(":herz:")
        XCTAssertGreaterThan(bitmap.byteColumns, 0)
        XCTAssertTrue(bitmap.bytes.contains { $0 != 0 })
    }

    func testTextIsUnchangedByTheNewParser() {
        // Die Zerlegung darf reinen Text nicht anders rastern als vorher.
        let rasterizer = TextRasterizer(rows: 11)
        let bitmap = rasterizer.rasterize("Lukas Köhl")
        XCTAssertEqual(bitmap.rows, 11)
        XCTAssertTrue(bitmap.bytes.contains { $0 != 0 })
    }
}
