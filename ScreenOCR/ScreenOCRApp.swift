//
//  ScreenOCRApp.swift
//  ScreenOCR
//
//  Created by Thomas Schalk on 23.03.25.
//

import SwiftUI
import Cocoa
import Vision
import Carbon
import Foundation
import AppKit
import UserNotifications

@main
struct ScreenOCRApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    var selectionWindow: SelectionWindow?
    private var hotkeyRef: EventHotKeyRef?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App ohne Dock-Icon laufen lassen
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
                
                if (error as NSError).domain == UNErrorDomain && (error as NSError).code == 1 {
                    // Berechtigung für Benachrichtigungen fehlt
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: "Benachrichtigungen deaktiviert",
                            message: "Bitte aktiviere Benachrichtigungen für diese App in den Systemeinstellungen.",
                            primaryButtonText: "Systemeinstellungen öffnen",
                            secondaryButtonText: "Abbrechen"
                        ) { openSettings in
                            if openSettings {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
                            }
                        }
                    }
                }
            }
        }
        
        setupStatusItem()
        setupHotkeyMonitoring()
        
        // Prüfe Bedienungshilfen-Berechtigung
        askForAccessibilityPermissionIfNeeded()
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Screen OCR")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "OCR aktivieren (⌘⇧O)", action: #selector(activateOCR), keyEquivalent: "O").keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func setupHotkeyMonitoring() {
        // Lokalen Monitor für Tastatureingaben einrichten (wenn App im Vordergrund ist)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.shift) &&
               event.keyCode == 31 { // 31 = O key
                self?.activateOCR()
                return nil // Event verbrauchen
            }
            return event
        }
        
        // Globalen Monitor für Tastatureingaben einrichten (wenn App im Hintergrund ist)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) &&
               event.modifierFlags.contains(.shift) &&
               event.keyCode == 31 { // 31 = O key
                self?.activateOCR()
            }
        }
    }
    
    func askForAccessibilityPermissionIfNeeded() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if !trusted {
            DispatchQueue.main.async {
                self.showAlert(
                    title: "Berechtigung erforderlich",
                    message: "Bitte aktiviere diese App unter Systemeinstellungen > Datenschutz & Sicherheit > Bedienungshilfen, damit der Hotkey funktioniert.",
                    primaryButtonText: "Systemeinstellungen öffnen",
                    secondaryButtonText: "Später"
                ) { openSettings in
                    if openSettings {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        }
    }
    
    func showAlert(title: String, message: String, primaryButtonText: String, secondaryButtonText: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primaryButtonText)
        alert.addButton(withTitle: secondaryButtonText)
        
        let response = alert.runModal()
        completion(response == .alertFirstButtonReturn)
    }
    
    @objc func statusItemClicked() {
        // Wird nicht direkt aufgerufen, da wir ein Menü haben,
        // aber könnte für zukünftige Erweiterungen nützlich sein
    }
    
    @objc func activateOCR() {
        print("OCR aktiviert")
        
        // Bestehende Auswahlfenster schließen
        if selectionWindow != nil {
            selectionWindow?.close()
            selectionWindow = nil
        }
        
        // Neues Auswahlfenster erstellen und anzeigen
        selectionWindow = SelectionWindow()
        selectionWindow?.onSelectionComplete = { rect in
            self.performOCR(in: rect)
        }
        selectionWindow?.makeKeyAndOrderFront(nil)
    }
    
    func performOCR(in rect: NSRect) {
        // Create a new process to take screenshot using screencapture command
        captureUsingExternalCommand(rect: rect) { imagePath in
            guard let imagePath = imagePath, FileManager.default.fileExists(atPath: imagePath) else {
                self.showNotification(message: "Fehler beim Erstellen des Screenshots")
                return
            }
            
            // Load the captured image
            guard let nsImage = NSImage(contentsOfFile: imagePath),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                self.showNotification(message: "Fehler beim Laden des Screenshots")
                return
            }
            
            // Delete the temporary file
            try? FileManager.default.removeItem(atPath: imagePath)
            
            // OCR auf dem Bild durchführen
            let requestHandler = VNImageRequestHandler(cgImage: cgImage)
            let request = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    DispatchQueue.main.async {
                        self.showNotification(message: "Fehler bei der Texterkennung")
                    }
                    return
                }
                
                // Erkannten Text sammeln
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    if !recognizedText.isEmpty {
                        // Text in die Zwischenablage kopieren
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(recognizedText, forType: .string)
                        self.showNotification(message: "Text in die Zwischenablage kopiert")
                    } else {
                        self.showNotification(message: "Kein Text gefunden")
                    }
                }
            }
            
            // OCR-Optionen für deutsche und englische Sprache konfigurieren
            request.recognitionLanguages = ["de-DE", "en-US"]
            request.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("Fehler bei der OCR-Verarbeitung: \(error)")
                self.showNotification(message: "Fehler bei der Texterkennung")
            }
        }
    }
    
    private func captureUsingExternalCommand(rect: NSRect, completion: @escaping (String?) -> Void) {
        // Create a temporary file path
        let tempDir = NSTemporaryDirectory()
        let tempFilePath = tempDir + UUID().uuidString + ".png"
        
        // Prepare the screencapture command
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = [
            "-x",                               // No sound
            "-r",                               // Region capture
            "-R\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))",  // Region coordinates
            tempFilePath                        // Output file
        ]
        
        // Set up a pipe to capture output
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        // Launch the process
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                completion(tempFilePath)
            } else {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("Screencapture failed: \(output)")
                completion(nil)
            }
        } catch {
            print("Failed to launch screencapture: \(error)")
            completion(nil)
        }
    }
    
    func showNotification(message: String) {
        print("Notification: \(message)")
        
        // Zuerst versuchen wir es mit UserNotifications
        let content = UNMutableNotificationContent()
        content.title = "Screen OCR"
        content.body = message
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                           content: content,
                                           trigger: nil)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
                
                // Fallback: Anzeige eines kleinen Popup-Fensters
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Screen OCR"
                    alert.informativeText = message
                    alert.runModal()
                }
            }
        }
    }
    
    @objc func quitApp() {
        // Cleanup
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        
        NSApplication.shared.terminate(nil)
    }
}

// Hilfsfunktion zum Konvertieren eines Strings in einen OSType
func fourCharCodeFrom(_ string: String) -> FourCharCode {
    var result: FourCharCode = 0
    let bytes = string.utf8
    for byte in bytes {
        result = (result << 8) + FourCharCode(byte)
    }
    return result
}
