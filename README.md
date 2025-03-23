# ScreenOCR

ScreenOCR is a macOS application that allows you to select any text on your screen and convert it into editable text using Optical Character Recognition (OCR).  
Simply use the global hotkey, select an area of your screen, and the recognized text will be copied to your clipboard automatically.

---

## Features

- **Global Hotkey:** Press `Shift + Cmd + O` to activate the selection tool from anywhere.  
- **Simple Selection:** Draw a rectangle around the text you want to capture.  
- **Automatic OCR:** The text is automatically recognized within the selected area.  
- **Clipboard Integration:** The recognized text is copied directly to your clipboard.  

---

## Requirements

- macOS **15.2** or later  
- Screen capture permissions  
- Accessibility permissions for keyboard shortcuts  

---

## Installation

1. **Download** the latest version from the [Releases page](#).  
2. **Move** the `ScreenOCR` app to your `Applications` folder.  
3. **Launch** the app.  
4. **Grant** the required permissions when prompted.  

---

## Usage

1. **Press** `Shift + Cmd + O` to activate the selection tool.  
2. **Draw** a rectangle around the text you want to capture.  
3. **Click** **"Done"** to process the selection.  
4. The recognized text is automatically copied to your clipboard.  
5. **Paste** the text wherever you need it (e.g., in a document, email, etc.).  

---

## Permissions

ScreenOCR requires the following permissions to function properly:

- **Screen Capture:** To capture the screen area containing text.  
- **Accessibility:** To register the global hotkey (`Shift + Cmd + O`).  

When you first launch the app, you will be guided through the permission setup process.

---

## Development

### Prerequisites

- **Xcode 16.2** or later  
- **Swift 5.0**  
- **macOS 15.2 SDK** or later  

### Building from Source

1. **Clone the repository:**
   ```sh
   git clone https://github.com/yourusername/ScreenOCR.git
   ```
2. **Open the project in Xcode:**
    ```sh
    cd ScreenOCR
    open ScreenOCR.xcodeproj
    ```
3.	Build the project in Xcode: ⌘ + B

