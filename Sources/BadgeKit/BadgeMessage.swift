import Foundation

/// Anzeigeeffekt einer Nachricht. Die Rohwerte sind die `mode`-Nibbles des
/// Geräteprotokolls und dürfen nicht verändert werden.
public enum BadgeEffect: UInt8, CaseIterable, Codable, Sendable {
    case scrollLeft  = 0
    case scrollRight = 1
    case scrollUp    = 2
    case scrollDown  = 3
    case still       = 4
    case animation   = 5
    case dropDown    = 6
    case curtain     = 7
    case laser       = 8

    public var germanName: String {
        switch self {
        case .scrollLeft:  return "Nach links"
        case .scrollRight: return "Nach rechts"
        case .scrollUp:    return "Nach oben"
        case .scrollDown:  return "Nach unten"
        case .still:       return "Stehend"
        case .animation:   return "Animation"
        case .dropDown:    return "Herabfallen"
        case .curtain:     return "Vorhang"
        case .laser:       return "Laser"
        }
    }
}

/// Helligkeit. Das Gerät kennt genau vier Stufen.
public enum BadgeBrightness: Int, CaseIterable, Codable, Sendable {
    case p25  = 25
    case p50  = 50
    case p75  = 75
    case p100 = 100

    /// Byte an Offset 5 des Headers.
    public var headerByte: UInt8 {
        switch self {
        case .p25:  return 0x40
        case .p50:  return 0x20
        case .p75:  return 0x10
        case .p100: return 0x00
        }
    }

    public var germanName: String { "\(rawValue) %" }
}

/// Zeilenzahl der LED-Matrix. Die 1144er-Baureihe hat 11, die 1248er 12 Zeilen.
public enum BadgeRowCount: Int, CaseIterable, Codable, Sendable {
    case eleven = 11
    case twelve = 12

    public var germanName: String {
        switch self {
        case .eleven: return "11 Zeilen (S1144 / B1144 / GD1144)"
        case .twelve: return "12 Zeilen (S1248 / B1248 / GD1248)"
        }
    }
}

/// Eine der acht Nachrichten, die das Schild gleichzeitig speichern kann.
public struct BadgeMessage: Codable, Equatable, Sendable, Identifiable {
    public var id: Int
    public var text: String
    public var effect: BadgeEffect
    /// 1 = langsamste, 8 = schnellste Stufe.
    public var speed: Int
    public var blink: Bool
    public var border: Bool
    public var isEnabled: Bool

    public init(
        id: Int,
        text: String = "",
        effect: BadgeEffect = .scrollLeft,
        speed: Int = 4,
        blink: Bool = false,
        border: Bool = false,
        isEnabled: Bool = false
    ) {
        self.id = id
        self.text = text
        self.effect = effect
        self.speed = speed
        self.blink = blink
        self.border = border
        self.isEnabled = isEnabled
    }

    /// Speed auf den gültigen Bereich begrenzt.
    public var clampedSpeed: Int { min(max(speed, 1), 8) }

    /// Wird gesendet, wenn aktiviert und nicht leer.
    public var carriesContent: Bool {
        isEnabled && !text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Die acht Nachrichtenplätze plus die geräteweiten Einstellungen.
public struct BadgeDocument: Codable, Equatable, Sendable {
    public static let slotCount = 8

    public var messages: [BadgeMessage]
    public var brightness: BadgeBrightness
    public var rowCount: BadgeRowCount
    public var fontName: String
    public var fontSize: Double

    public init(
        messages: [BadgeMessage]? = nil,
        brightness: BadgeBrightness = .p100,
        rowCount: BadgeRowCount = .eleven,
        fontName: String = TextRasterizer.defaultFontName,
        fontSize: Double = TextRasterizer.defaultFontSize
    ) {
        self.messages = messages ?? (0..<Self.slotCount).map { index in
            BadgeMessage(id: index, isEnabled: index == 0)
        }
        self.brightness = brightness
        self.rowCount = rowCount
        self.fontName = fontName
        self.fontSize = fontSize
    }
}
