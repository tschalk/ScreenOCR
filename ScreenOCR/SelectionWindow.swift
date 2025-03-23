import SwiftUI

struct SelectionWindow: View {
    @State private var selectedText: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Ziehe ein Rechteck, um den Bereich auszuwählen")
                .font(.headline)
            
            Button("Fertig") {
                // Dummy-OCR-Funktion aufrufen und Text kopieren
                let ocrText = performOCR()
                copyToClipboard(text: ocrText)
                
                // Auswahlfenster schließen
                if let window = NSApplication.shared.keyWindow {
                    window.close()
                }
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
    
    func performOCR() -> String {
        // Hier kommt deine OCR-Implementierung hin
        return "Erkannter Text"
    }
    
    func copyToClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

struct SelectionWindow_Previews: PreviewProvider {
    static var previews: some View {
        SelectionWindow()
    }
}
