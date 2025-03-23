import Cocoa

class SelectionWindow: NSWindow {
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint?
    private var selectionView: SelectionView!
    
    var onSelectionComplete: ((NSRect) -> Void)?
    
    init() {
        // Bildschirmgröße ermitteln
        let screenFrame = NSScreen.main?.frame ?? .zero
        
        // Fenster über den gesamten Bildschirm erstellen
        super.init(contentRect: screenFrame,
                   styleMask: [.borderless],
                   backing: .buffered,
                   defer: false)
        
        // Fenster konfigurieren
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // SelectionView erstellen und als Content View setzen
        selectionView = SelectionView(frame: screenFrame)
        selectionView.window = self
        self.contentView = selectionView
        
        // Event-Monitoring starten
        startEventMonitoring()
    }
    
    private func startEventMonitoring() {
        // Lokalen Event-Monitor für Mausklicks und Tastenanschläge einrichten
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .keyDown, .mouseMoved]) { [weak self] event in
            guard let self = self else { return event }
            
            switch event.type {
            case .leftMouseDown:
                if self.startPoint == nil {
                    // Ersten Klick erfassen
                    self.startPoint = event.locationInWindow
                    self.currentPoint = event.locationInWindow
                    self.selectionView.setStartPoint(self.startPoint!)
                    self.selectionView.setEndPoint(self.currentPoint!)
                    self.selectionView.needsDisplay = true
                } else {
                    // Zweiten Klick erfassen und Rechteck abschließen
                    self.currentPoint = event.locationInWindow
                    self.selectionView.setEndPoint(self.currentPoint!)
                    self.selectionView.needsDisplay = true
                    
                    // Ausgewähltes Rechteck berechnen
                    let rect = self.calculateSelectionRect()
                    
                    // Fenster schließen
                    self.close()
                    
                    // Callback mit dem ausgewählten Rechteck aufrufen
                    self.onSelectionComplete?(rect)
                }
                return nil
                
            case .leftMouseUp:
                return nil
                
            case .mouseMoved:
                if self.startPoint != nil {
                    // Mausbewegung nach dem ersten Klick verfolgen
                    self.currentPoint = event.locationInWindow
                    self.selectionView.setEndPoint(self.currentPoint!)
                    self.selectionView.needsDisplay = true
                }
                return event
                
            case .keyDown:
                if event.keyCode == 53 { // ESC-Taste
                    self.close()
                    return nil
                }
                return event
                
            default:
                return event
            }
        }
        
        // Cursor auf Fadenkreuz ändern
        NSCursor.crosshair.set()
    }
    
    private func calculateSelectionRect() -> NSRect {
        guard let start = startPoint, let end = currentPoint else {
            return .zero
        }
        
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    override func close() {
        // Event-Monitoring beenden
        super.close()
        NSCursor.arrow.set()
    }
}

class SelectionView: NSView {
    private var startPoint: NSPoint?
    private var endPoint: NSPoint?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor(white: 0, alpha: 0.1).cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setStartPoint(_ point: NSPoint) {
        startPoint = point
    }
    
    func setEndPoint(_ point: NSPoint) {
        endPoint = point
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let start = startPoint, let end = endPoint else {
            return
        }
        
        // Auswahlrechteck zeichnen
        let x = min(start.x, end.x)
        let y = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        
        let selectionRect = NSRect(x: x, y: y, width: width, height: height)
        
        // Auswahlpfad erstellen
        let selectionPath = NSBezierPath(rect: selectionRect)
        
        // Durchsichtige Füllung mit Blauton
        NSColor(calibratedRed: 0.3, green: 0.3, blue: 1.0, alpha: 0.2).setFill()
        selectionPath.fill()
        
        // Roten Rand zeichnen
        NSColor.red.setStroke()
        selectionPath.lineWidth = 2.0
        selectionPath.stroke()
    }
}
