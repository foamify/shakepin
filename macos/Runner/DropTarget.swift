import AppKit
import FlutterMacOS
import Foundation

class DropTarget: NSView {

    let label: String
    private let channel: FlutterMethodChannel

    init(frame: NSRect, label: String, channel: FlutterMethodChannel) {
        self.label = label
        self.channel = channel
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let position = sender.draggingLocation
        channel.invokeMethod("dragEnter", arguments: [label, position.x, position.y])
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        channel.invokeMethod("dragExited", arguments: label)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let position = sender.draggingLocation
        channel.invokeMethod("dragUpdated", arguments: [label, position.x, position.y])
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        var paths: [String] = []

        for item in pasteboard.pasteboardItems ?? [] {
            if let imageData = item.data(forType: .tiff) {
                let path = saveDataToTemp(data: imageData, prefix: "temp_file_", extension: "tiff")
                paths.append(path)
                NSLog("Saved TIFF image: \(path)")
            } else if let imageData = item.data(forType: .png) {
                let path = saveDataToTemp(data: imageData, prefix: "temp_file_", extension: "png")
                paths.append(path)
                NSLog("Saved PNG image: \(path)")
            } else if let urlString = item.string(forType: .fileURL),
                let url = URL(string: urlString)
            {
                paths.append(url.standardized.path)
                NSLog("Added file URL path: \(url.standardized.path)")
            } else if let urlString = item.string(forType: .URL), let url = URL(string: urlString) {
                paths.append(url.standardized.path)
                NSLog("Added URL path: \(url.standardized.path)")
                // } else if let colorData = item.data(forType: .color),
                //     let color = NSColor(data: colorData)
                // {
                //     paths.append(saveColorToTemp(color: color))
            } else if let rtfData = item.data(forType: .rtf) {
                let path = saveDataToTemp(data: rtfData, prefix: "temp_file_", extension: "rtf")
                paths.append(path)
                NSLog("Saved RTF data: \(path)")
            } else if let rtfdData = item.data(forType: .rtfd) {
                let path = saveDataToTemp(data: rtfdData, prefix: "temp_file_", extension: "rtfd")
                paths.append(path)
                NSLog("Saved RTFD data: \(path)")
            } else if let htmlData = item.data(forType: .html) {
                let path = saveDataToTemp(data: htmlData, prefix: "temp_file_", extension: "html")
                paths.append(path)
                NSLog("Saved HTML data: \(path)")
            } else if let pdfData = item.data(forType: .pdf) {
                let path = saveDataToTemp(data: pdfData, prefix: "temp_file_", extension: "pdf")
                paths.append(path)
                NSLog("Saved PDF data: \(path)")
            } else if let tabularText = item.string(forType: .tabularText) {
                let path = saveStringToTemp(
                    string: tabularText, prefix: "temp_file_", extension: "txt")
                paths.append(path)
                NSLog("Saved tabular text: \(path)")
                // } else if let fontData = item.data(forType: .font),
                //     let font = NSFont(data: fontData, size: 0)
                // {
                //     paths.append(saveFontToTemp(font: font))
            } else if let soundData = item.data(forType: .sound) {
                let path = saveDataToTemp(data: soundData, prefix: "temp_file_", extension: "aiff")
                paths.append(path)
                NSLog("Saved sound data: \(path)")
            } else if let string = item.string(forType: .string) {
                let path = saveStringToTemp(string: string, prefix: "temp_file_", extension: "txt")
                paths.append(path)
                NSLog("Saved string: \(path)")
            } else if let fileContents = item.data(forType: .fileContents) {
                let path = saveDataToTemp(
                    data: fileContents, prefix: "temp_file_", extension: "dat")
                paths.append(path)
                NSLog("Saved file contents: \(path)")
            } else {
                NSLog("Unhandled pasteboard item type")
            }
        }

        if !paths.isEmpty {
            channel.invokeMethod("dragPerform", arguments: [label, paths])
            return true
        }

        return false
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        channel.invokeMethod("dragConclude", arguments: nil)
    }

    // Helper functions for saving data to temporary files
    private func saveDataToTemp(data: Data, prefix: String, extension: String) -> String {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "\(prefix)\(UUID().uuidString).\(`extension`)"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            NSLog("Error saving data: \(error)")
            return ""
        }
    }

    private func saveStringToTemp(string: String, prefix: String, extension: String) -> String {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "\(prefix)\(UUID().uuidString).\(`extension`)"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try string.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL.standardized.path
        } catch {
            NSLog("Error saving string: \(error)")
            return ""
        }
    }

    private func saveColorToTemp(color: NSColor) -> String {
        let colorString =
            "R: \(color.redComponent), G: \(color.greenComponent), B: \(color.blueComponent), A: \(color.alphaComponent)"
        return saveStringToTemp(string: colorString, prefix: "temp_file_", extension: "txt")
    }

    private func saveFontToTemp(font: NSFont) -> String {
        let fontString = "Font Name: \(font.fontName), Size: \(font.pointSize)"
        return saveStringToTemp(string: fontString, prefix: "temp_file_", extension: "txt")
    }
}
