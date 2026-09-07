import AppKit
import BadgeKit
import SwiftUI

@main
struct NamensschildApp: App {
    @State private var model = AppModel()

    init() {
        // Auch außerhalb eines App-Bundles als reguläre Anwendung starten.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        Window("Namensschild", id: "main") {
            ContentView(model: model)
                .onAppear { NSApp.activate(ignoringOtherApps: true) }
        }
        .defaultSize(width: 900, height: 660)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neu") { model.reset() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Öffnen …") { model.open() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Sichern unter …") { model.saveCopy() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            CommandMenu("Schild") {
                Button("Senden") { model.send() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.canSend)
                Button("Testmuster senden") { model.sendTestPattern() }
                    .disabled(!model.isConnected)
            }
        }
    }
}
