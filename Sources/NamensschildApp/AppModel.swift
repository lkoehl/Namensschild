import AppKit
import BadgeKit
import Combine
import Foundation
import Observation

@Observable
final class AppModel {
    var document = BadgeDocument()

    /// Welche der acht Nachrichten die Vorschau zeigt.
    var selectedSlot = 0

    private(set) var connectedDevices: [BadgeDeviceInfo] = []
    private(set) var bitmaps: [ColumnBitmap] = []
    private(set) var usedColumns = 0
    private(set) var columnBudget = BadgeProtocol.columnBudget(rows: 11)
    private(set) var isSending = false
    private(set) var status: Status = .idle

    enum Status: Equatable {
        case idle
        case working(String)
        case success(String)
        case failure(String)

        var message: String? {
            switch self {
            case .idle: return nil
            case let .working(text), let .success(text), let .failure(text): return text
            }
        }
    }

    var isConnected: Bool { !connectedDevices.isEmpty }
    var canSend: Bool { isConnected && !isSending && !overBudget && hasContent }
    var overBudget: Bool { usedColumns > columnBudget }
    var hasContent: Bool { document.messages.contains { $0.carriesContent } }

    /// Sichtbare Spalten der echten Matrix — 44 bei elf, 48 bei zwölf Zeilen.
    var displayColumns: Int { document.rowCount == .eleven ? 44 : 48 }

    private var rasterizer: TextRasterizer {
        TextRasterizer(
            fontName: document.fontName,
            fontSize: document.fontSize,
            rows: document.rowCount.rawValue
        )
    }

    /// Passen große Umlaute und Unterlängen gleichzeitig auf die Matrix?
    private(set) var fontFits = true
    /// Die größte Schriftgröße, bei der beides noch vollständig zu sehen ist.
    private(set) var largestFittingFontSize: Double = TextRasterizer.defaultFontSize

    func shrinkFontToFit() {
        document.fontSize = largestFittingFontSize
        documentDidChange()
    }

    private let monitor = BadgeDeviceMonitor()
    private var statusResetWorkItem: DispatchWorkItem?
    private var saveWorkItem: DispatchWorkItem?

    init() {
        if let stored = DocumentStore.load() {
            document = stored
        }
        recompute()
        monitor.onChange = { [weak self] devices in
            self?.connectedDevices = devices
        }
        monitor.start()
        connectedDevices = BadgeDevice.connectedDeviceInfos()
    }

    // MARK: - Ableitungen

    /// Wird von der Oberfläche aufgerufen, sobald sich am Dokument etwas ändert.
    func documentDidChange() {
        recompute()
        scheduleSave()
    }

    private func recompute() {
        bitmaps = BadgeJob.rasterizeAll(document)
        let probe = rasterizer
        fontFits = probe.fitsRows
        largestFittingFontSize = probe.largestFittingSize()
        columnBudget = BadgeProtocol.columnBudget(rows: document.rowCount.rawValue)
        usedColumns = zip(document.messages, bitmaps).reduce(0) { total, pair in
            total + (pair.0.carriesContent ? pair.1.byteColumns : 0)
        }
    }

    func bitmap(for slot: Int) -> ColumnBitmap {
        guard bitmaps.indices.contains(slot) else {
            return ColumnBitmap(rows: document.rowCount.rawValue, byteColumns: 0)
        }
        return bitmaps[slot]
    }

    // MARK: - Senden

    func send() {
        guard !isSending else { return }
        do {
            let plan = try BadgeJob.build(document: document)
            transmit(plan.payload, describing: "\(plan.payload.count) Bytes an das Schild")
        } catch {
            setStatus(.failure(error.localizedDescription))
        }
    }

    func sendTestPattern() {
        guard !isSending else { return }
        do {
            let payload = try BadgeJob.testPatternPayload(rows: document.rowCount, brightness: document.brightness)
            transmit(payload, describing: "Testmuster")
        } catch {
            setStatus(.failure(error.localizedDescription))
        }
    }

    private func transmit(_ payload: Data, describing what: String) {
        isSending = true
        setStatus(.working("Sende \(what) …"), autoReset: false)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try BadgeDevice.send(payload: payload) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSending = false
                switch result {
                case .success:
                    self.setStatus(.success("Übertragen: \(what)."))
                case let .failure(error):
                    self.setStatus(.failure(error.localizedDescription))
                }
            }
        }
    }

    private func setStatus(_ new: Status, autoReset: Bool = true) {
        statusResetWorkItem?.cancel()
        status = new
        guard autoReset else { return }
        let item = DispatchWorkItem { [weak self] in self?.status = .idle }
        statusResetWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: item)
    }

    // MARK: - Dokument

    func reset() {
        document = BadgeDocument()
        selectedSlot = 0
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let snapshot = document
        let item = DispatchWorkItem { DocumentStore.save(snapshot) }
        saveWorkItem = item
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    func saveCopy() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Namensschild.badge"
        panel.allowedContentTypes = []
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try DocumentStore.encoder.encode(document).write(to: url)
            setStatus(.success("Gesichert: \(url.lastPathComponent)"))
        } catch {
            setStatus(.failure("Sichern fehlgeschlagen: \(error.localizedDescription)"))
        }
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            document = try DocumentStore.decoder.decode(BadgeDocument.self, from: Data(contentsOf: url))
            setStatus(.success("Geladen: \(url.lastPathComponent)"))
        } catch {
            setStatus(.failure("Die Datei ließ sich nicht lesen: \(error.localizedDescription)"))
        }
    }
}

/// Merkt sich den zuletzt benutzten Nachrichtensatz.
enum DocumentStore {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    static let decoder = JSONDecoder()

    static var url: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let folder = base.appendingPathComponent("Namensschild", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("Zuletzt.badge")
    }

    static func load() -> BadgeDocument? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(BadgeDocument.self, from: data)
    }

    static func save(_ document: BadgeDocument) {
        guard let url, let data = try? encoder.encode(document) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
