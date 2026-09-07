import BadgeKit
import Foundation

// Kleines Werkzeug zum Prüfen von Rasterung, Protokoll und Übertragung —
// die Oberfläche baut auf denselben Bausteinen auf.

let usage = """
badgectl — ALLNET LED-Namensschild von der Kommandozeile

  badgectl devices
  badgectl send <Text> [Optionen]
  badgectl preview <Text> [Optionen]     Vorschau als ASCII-Grafik, ohne Gerät
  badgectl fonts [<Text>]                Schriften im Vergleich
  badgectl test                          Vollflächiges Muster (Zeilen abzählen)
  badgectl hexdump <Text> [Optionen]     Bytestrom anzeigen

Optionen:
  --effect <name>    \(BadgeEffect.allCases.map { $0.cliName }.joined(separator: ", "))
  --speed <1-8>      Vorgabe 4
  --brightness <25|50|75|100>
  --rows <11|12>     Vorgabe 11
  --font <Name>      Vorgabe \(TextRasterizer.defaultFontName)
  --size <Punkte>    Vorgabe \(Int(TextRasterizer.defaultFontSize))
  --blink            Blinken einschalten
  --border           Lauflicht-Rahmen einschalten
"""

extension BadgeEffect {
    var cliName: String {
        switch self {
        case .scrollLeft:  return "left"
        case .scrollRight: return "right"
        case .scrollUp:    return "up"
        case .scrollDown:  return "down"
        case .still:       return "still"
        case .animation:   return "animation"
        case .dropDown:    return "drop"
        case .curtain:     return "curtain"
        case .laser:       return "laser"
        }
    }

    static func named(_ name: String) -> BadgeEffect? {
        allCases.first { $0.cliName == name.lowercased() }
    }
}

struct Options {
    var effect: BadgeEffect = .scrollLeft
    var speed = 4
    var brightness: BadgeBrightness = .p100
    var rows: BadgeRowCount = .eleven
    var font = TextRasterizer.defaultFontName
    var size = TextRasterizer.defaultFontSize
    var blink = false
    var border = false
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("Fehler: " + message + "\n").utf8))
    exit(1)
}

func parse(_ arguments: [String]) -> (positional: [String], options: Options) {
    var options = Options()
    var positional: [String] = []
    var index = 0
    func next(_ flag: String) -> String {
        index += 1
        guard index < arguments.count else { fail("\(flag) erwartet einen Wert.") }
        return arguments[index]
    }
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--effect":
            let name = next(argument)
            guard let effect = BadgeEffect.named(name) else { fail("Unbekannter Effekt '\(name)'.") }
            options.effect = effect
        case "--speed":
            guard let value = Int(next(argument)), (1...8).contains(value) else { fail("--speed braucht 1 bis 8.") }
            options.speed = value
        case "--brightness":
            guard let value = Int(next(argument)), let level = BadgeBrightness(rawValue: value) else {
                fail("--brightness braucht 25, 50, 75 oder 100.")
            }
            options.brightness = level
        case "--rows":
            guard let value = Int(next(argument)), let rows = BadgeRowCount(rawValue: value) else {
                fail("--rows braucht 11 oder 12.")
            }
            options.rows = rows
        case "--font":
            options.font = next(argument)
        case "--size":
            guard let value = Double(next(argument)), value > 0 else { fail("--size braucht eine positive Zahl.") }
            options.size = value
        case "--blink":  options.blink = true
        case "--border": options.border = true
        case "-h", "--help":
            print(usage)
            exit(0)
        default:
            positional.append(argument)
        }
        index += 1
    }
    return (positional, options)
}

func document(text: String, options: Options) -> BadgeDocument {
    var doc = BadgeDocument(
        brightness: options.brightness,
        rowCount: options.rows,
        fontName: options.font,
        fontSize: options.size
    )
    doc.messages[0] = BadgeMessage(
        id: 0,
        text: text,
        effect: options.effect,
        speed: options.speed,
        blink: options.blink,
        border: options.border,
        isEnabled: true
    )
    return doc
}

func printFrame(_ bitmap: ColumnBitmap) {
    let border = String(repeating: "─", count: bitmap.pixelWidth)
    print("┌\(border)┐")
    for line in bitmap.asciiArt(on: "█", off: " ").split(separator: "\n", omittingEmptySubsequences: false) {
        print("│\(line)│")
    }
    print("└\(border)┘")
    print("\(bitmap.pixelWidth) Pixel breit · \(bitmap.byteColumns) Byte-Spalten · \(bitmap.rows) Zeilen")
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    print(usage)
    exit(0)
}
let (positional, options) = parse(Array(arguments.dropFirst()))

switch command {
case "devices":
    let devices = BadgeDevice.connectedDeviceInfos()
    if devices.isEmpty {
        print("Kein Schild gefunden (gesucht wird VID 0x0416 / PID 0x5020).")
        exit(2)
    }
    for device in devices {
        print("• \(device.displayName)  [Location 0x\(String(device.id, radix: 16))]")
    }

case "preview":
    guard let text = positional.first else { fail("Bitte einen Text angeben.") }
    let rasterizer = TextRasterizer(fontName: options.font, fontSize: options.size, rows: options.rows.rawValue)
    printFrame(rasterizer.rasterize(text))

case "fonts":
    let text = positional.first ?? "Größe? Äöüß 123"
    for name in TextRasterizer.recommendedFonts {
        for size in [10.0, 11.0, 12.0] {
            let rasterizer = TextRasterizer(fontName: name, fontSize: size, rows: options.rows.rawValue)
            let bitmap = rasterizer.rasterize(text)
            print("\n── \(name) @ \(Int(size)) pt ──")
            printFrame(bitmap)
        }
    }

case "hexdump":
    guard let text = positional.first else { fail("Bitte einen Text angeben.") }
    do {
        let plan = try BadgeJob.build(document: document(text: text, options: options))
        for (index, report) in BadgeProtocol.reports(from: plan.payload).enumerated() {
            let hex = report.map { String(format: "%02X", $0) }.joined(separator: " ")
            print(String(format: "%04X  %@", index * 64, hex))
        }
        print("\n\(plan.payload.count) Bytes · \(plan.usedColumns)/\(plan.columnBudget) Byte-Spalten belegt")
    } catch {
        fail(error.localizedDescription)
    }

case "send":
    guard let text = positional.first else { fail("Bitte einen Text angeben.") }
    do {
        let plan = try BadgeJob.build(document: document(text: text, options: options))
        if let bitmap = plan.slots.first?.bitmap { printFrame(bitmap) }
        try BadgeDevice.send(payload: plan.payload)
        print("Gesendet: \(plan.payload.count) Bytes, \(BadgeProtocol.reports(from: plan.payload).count) Blöcke.")
    } catch {
        fail(error.localizedDescription)
    }

case "test":
    do {
        let payload = try BadgeJob.testPatternPayload(rows: options.rows, brightness: options.brightness)
        try BadgeDevice.send(payload: payload)
        print("Testmuster gesendet (\(options.rows.rawValue) Zeilen). Zähle die leuchtenden Reihen ab.")
    } catch {
        fail(error.localizedDescription)
    }

default:
    print(usage)
    exit(1)
}
