import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("OCR App läuft. Drücke Shift+Cmd+O zum Auswahlbereich")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
