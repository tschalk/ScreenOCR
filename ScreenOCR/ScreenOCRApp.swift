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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App ohne Dock-Icon laufen lassen
        NSApp.setActivationPolicy(.accessory)
        
        setupStatusItem()
        registerHotkey()
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
        menu.addItem(NSMenuItem(title: "OCR aktivieren (⌘⇧O)", action: #selector(activateOCR), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    func registerHotkey() {
        // Globale Tastenkombination Cmd+Shift+O registrieren
        var keyID = EventHotKeyID(signature: OSType(fourCharCodeFrom: "SOCR"), id: 1)
        
        let keyCode = UInt32(kVK_ANSI_O)
        let modifiers = UInt32(cmdKey | shiftKey)
        
        var hotKeyRef: EventHotKeyRef?
        let registerErr = RegisterEventHotKey(keyCode, modifiers, keyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        
        if registerErr == noErr {
            self.hotkeyRef = hotKeyRef
            
            // Event-Handler für Hotkey
            NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) &&
                   event.modifierFlags.contains(.shift) &&
                   event.keyCode == UInt16(kVK_ANSI_O) {
                    self.activateOCR()
                }
            }
        } else {
            print("Fehler beim Registrieren der Tastenkombination: \(registerErr)")
            // Fallback-Methode für Hotkey-Registrierung
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            let trusted = AXIsProcessTrustedWithOptions(options)
            print("App vertrauenswürdig: \(trusted)")
        }
    }
    
    @objc func statusItemClicked() {
        // Wird nicht direkt aufgerufen, da wir ein Menü haben,
        // aber könnte für zukünftige Erweiterungen nützlich sein
    }
    
    @objc func activateOCR() {
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
        // Screenshot des ausgewählten Bereichs erstellen
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID(),
                                                rect: CGRect(x: rect.origin.x,
                                                            y: rect.origin.y,
                                                            width: rect.size.width,
                                                            height: rect.size.height))
        else {
            showNotification(message: "Fehler beim Erstellen des Screenshots")
            return
        }
        
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
            showNotification(message: "Fehler bei der Texterkennung")
        }
    }
    
    func showNotification(message: String) {
        let notification = NSUserNotification()
        notification.title = "Screen OCR"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    @objc func quitApp() {
        // Unregister hotkey
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
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
