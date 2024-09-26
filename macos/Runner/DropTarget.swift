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
        channel.invokeMethod("dragPerform", arguments: label)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        channel.invokeMethod("dragConclude", arguments: nil)
    }

}
