import Foundation
import IOKit
import IOKit.hid

public enum BadgeDeviceError: Error, LocalizedError {
    case notFound
    case openFailed(IOReturn)
    case writeFailed(block: Int, status: IOReturn)

    public var errorDescription: String? {
        switch self {
        case .notFound:
            return "Kein Namensschild gefunden. Steckt das USB-Kabel, und ist das Schild eingeschaltet?"
        case let .openFailed(status):
            return "Das Schild ließ sich nicht öffnen (\(BadgeDeviceError.describe(status))). Läuft noch ein anderes Programm, das darauf zugreift?"
        case let .writeFailed(block, status):
            return "Übertragung bei Block \(block) abgebrochen (\(BadgeDeviceError.describe(status)))."
        }
    }

    static func describe(_ status: IOReturn) -> String {
        switch status {
        case kIOReturnSuccess:      return "OK"
        case kIOReturnNotOpen:      return "Gerät nicht geöffnet"
        case kIOReturnExclusiveAccess: return "Gerät ist belegt"
        case kIOReturnNoDevice:     return "Gerät verschwunden"
        case kIOReturnNotPermitted: return "Zugriff verweigert"
        case kIOReturnTimeout:      return "Zeitüberschreitung"
        case kIOReturnUnsupported:  return "nicht unterstützt"
        default:                    return String(format: "IOReturn 0x%08X", UInt32(bitPattern: status))
        }
    }
}

/// Beschreibung eines angeschlossenen Schilds — für Anzeige und Auswahl.
public struct BadgeDeviceInfo: Identifiable, Equatable, Sendable {
    public let id: UInt64
    public let productName: String
    public let manufacturer: String

    public var displayName: String {
        let name = productName.isEmpty ? "LED-Namensschild" : productName
        return manufacturer.isEmpty ? name : "\(manufacturer) \(name)"
    }
}

/// Der Zugang zum Schild. Ersetzt das, was unter Windows ein Treiber wäre:
/// macOS spricht USB-HID über IOKit, ganz ohne Kernel-Erweiterung.
public enum BadgeDevice {
    public static let vendorID = 0x0416
    public static let productID = 0x5020

    static func matchingDictionary() -> CFDictionary {
        [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDProductIDKey: productID,
        ] as CFDictionary
    }

    static func info(for device: IOHIDDevice) -> BadgeDeviceInfo {
        let location = (IOHIDDeviceGetProperty(device, kIOHIDLocationIDKey as CFString) as? UInt64) ?? 0
        let product = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? ""
        let vendor = (IOHIDDeviceGetProperty(device, kIOHIDManufacturerKey as CFString) as? String) ?? ""
        return BadgeDeviceInfo(id: location, productName: product, manufacturer: vendor)
    }

    /// Alle passenden Geräte, die gerade angesteckt sind.
    public static func connectedDevices() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, matchingDictionary())
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return set.sorted { info(for: $0).id < info(for: $1).id }
    }

    public static func connectedDeviceInfos() -> [BadgeDeviceInfo] {
        connectedDevices().map(info(for:))
    }

    /// Schickt einen fertig kodierten Puffer an das erste (oder ein bestimmtes) Schild.
    public static func send(payload: Data, to deviceID: UInt64? = nil) throws {
        let devices = connectedDevices()
        let device: IOHIDDevice?
        if let deviceID {
            device = devices.first { info(for: $0).id == deviceID } ?? devices.first
        } else {
            device = devices.first
        }
        guard let device else { throw BadgeDeviceError.notFound }

        let openStatus = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openStatus == kIOReturnSuccess else { throw BadgeDeviceError.openFailed(openStatus) }
        defer { IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone)) }

        for (index, report) in BadgeProtocol.reports(from: payload).enumerated() {
            let status = report.withUnsafeBytes { raw -> IOReturn in
                guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return kIOReturnBadArgument }
                // Report-ID 0: das Gerät nutzt unnummerierte Output-Reports.
                return IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, base, report.count)
            }
            guard status == kIOReturnSuccess else {
                throw BadgeDeviceError.writeFailed(block: index, status: status)
            }
            // Die Firmware verdaut die Blöcke nicht beliebig schnell.
            usleep(2000)
        }
    }
}

/// Meldet das An- und Abstecken des Schilds, damit die Oberfläche nicht pollen muss.
public final class BadgeDeviceMonitor {
    public private(set) var devices: [BadgeDeviceInfo] = []
    /// Wird auf dem Hauptthread aufgerufen, wenn sich die Geräteliste ändert.
    public var onChange: (([BadgeDeviceInfo]) -> Void)?

    private var manager: IOHIDManager?

    public init() {}

    deinit { stop() }

    public func start() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, BadgeDevice.matchingDictionary())

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOHIDDeviceCallback = { context, _, _, _ in
            guard let context else { return }
            let monitor = Unmanaged<BadgeDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            monitor.refresh()
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, callback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, callback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        self.manager = manager
        refresh()
    }

    public func stop() {
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
    }

    private func refresh() {
        // Die Callbacks feuern, während IOKit die Geräteliste noch umbaut;
        // ein Hüpfer über die Hauptschleife liefert den stabilen Zustand.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let current = BadgeDevice.connectedDeviceInfos()
            guard current != self.devices else { return }
            self.devices = current
            self.onChange?(current)
        }
    }
}
