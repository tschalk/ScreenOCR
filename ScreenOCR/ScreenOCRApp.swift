import SwiftUI

@main
struct ScreenOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hotKeyMonitor: Any?
    var selectionWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        registerHotKey()
    }
    
    func registerHotKey() {
        // Globaler Monitor für Tastendrücke
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Prüfen, ob Shift+Cmd+O gedrückt wurde
            if event.modifierFlags.contains([.shift, .command]) && event.charactersIgnoringModifiers?.lowercased() == "o" {
                DispatchQueue.main.async {
                    self?.toggleSelectionWindow()
                }
            }
        }
    }
    
    func toggleSelectionWindow() {
        // Falls das Auswahlfenster bereits sichtbar ist, schließen
        if let window = selectionWindowController?.window, window.isVisible {
            window.close()
            selectionWindowController = nil
        } else {
            // Neues Auswahlfenster erstellen und anzeigen
            let selectionWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false)
            selectionWindow.center()
            selectionWindow.title = "Bereich auswählen"
            selectionWindow.contentView = NSHostingView(rootView: SelectionWindow())
            selectionWindowController = NSWindowController(window: selectionWindow)
            selectionWindowController?.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = hotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
