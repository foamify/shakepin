import AppKit
import Cocoa
import Compression
import FlutterMacOS

class MainFlutterWindow: NSWindow {

  var statusItem: NSStatusItem!
  var channel: FlutterMethodChannel!
  var flutterViewController: FlutterViewController!
  var dropTargets: [DropTarget] = []
  var dragSource: DragSource!
  var initialized = false
  var compressing = false

  var iconCache = NSCache<NSString, NSImage>()

  override func awakeFromNib() {
    cleanup()
    flutterViewController = FlutterViewController()

    RegisterGeneratedPlugins(registry: flutterViewController)

    channel = FlutterMethodChannel(
      name: "click.shakepin.macos/drop",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler(handleMethodCall)

    dragSource = DragSource(channel: channel)
    flutterViewController.view.addSubview(dragSource, positioned: .below, relativeTo: nil)

    setupWindow(flutterViewController)

    setupShakeDetector()

    setupMenuBar()

    super.awakeFromNib()
  }

  override func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)

    if !initialized {
      self.setIsVisible(false)
    }
    initialized = true
  }

  override var isKeyWindow: Bool {
    return true
  }

  func setupWindow(_ flutterViewController: FlutterViewController) {

    self.contentViewController = flutterViewController
    flutterViewController.backgroundColor = .clear

    self.isOpaque = false
    self.backgroundColor = .clear
    self.styleMask = [.fullSizeContentView, .resizable, .borderless]
    self.contentView?.layer?.cornerRadius = 12
    self.contentView?.layer?.masksToBounds = true

    let effectView = NSVisualEffectView()
    effectView.autoresizingMask = [.width, .height]
    effectView.blendingMode = .behindWindow
    effectView.material = .menu
    effectView.state = .active
    effectView.frame = flutterViewController.view.bounds
    self.contentView?.addSubview(
      effectView, positioned: .below, relativeTo: flutterViewController.view)

    flutterViewController.view.layer?.borderWidth = 1
    flutterViewController.view.layer?.borderColor = NSColor.systemGray.cgColor.copy(alpha: 0.5)

    // self.standardWindowButton(.closeButton)?.isHidden = true
    // self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    // self.standardWindowButton(.zoomButton)?.isHidden = true

    // self.titleVisibility = .hidden
    // self.titlebarAppearsTransparent = true
    self.level = .floating
    self.hasShadow = true

    self.collectionBehavior.insert(.canJoinAllSpaces)
    self.collectionBehavior.insert(.fullScreenPrimary)
    self.collectionBehavior.insert(.stationary)
    self.collectionBehavior.insert(.transient)
    if #available(macOS 13.0, *) {
      self.collectionBehavior.insert(.canJoinAllApplications)
    }
  }

  func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "cleanup":
      cleanup()
      result(nil)
    case "setTrayIcon":
      if let trayIconData = call.arguments as? FlutterStandardTypedData {
        let icon = NSImage(data: trayIconData.data)
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = icon
      }
      result(nil)
    case "hide":
      self.setIsVisible(false)
      result(nil)
    case "performDragWindow":
      if self.currentEvent != nil {
        self.performDrag(with: self.currentEvent!)
      }
    case "performDragSession":
      let fileURLs = call.arguments as! [String]
      performDragSession(fileURLs: fileURLs)

    case "getFileIcon":
      if let path = call.arguments as? String {
        getFileIcon(path: path, result: result)
      } else {
        result(
          FlutterError(code: "INVALID_ARGUMENT", message: "Path must be a string", details: nil))
      }

    case "setFrame":
      if let args = call.arguments as? [CGFloat?], args.count == 5 {
        let x = args[0] ?? self.frame.origin.x
        let y = args[1] ?? self.frame.origin.y
        let width = args[2] ?? self.frame.width
        let height = args[3] ?? self.frame.height
        let animate = args[4] != 0

        // Get the current mouse location and the screen containing it
        let mouseLocation = NSEvent.mouseLocation
        guard
          let screen = NSScreen.screens.first(where: {
            NSMouseInRect(mouseLocation, $0.frame, false)
          })
        else {
          result(
            FlutterError(
              code: "NO_SCREEN", message: "Unable to determine current screen", details: nil))
          return
        }

        // Constrain the frame to the screen bounds
        let screenFrame = screen.visibleFrame
        let constrainedX = max(screenFrame.minX, min(x, screenFrame.maxX - width))
        let constrainedY = max(screenFrame.minY, min(y, screenFrame.maxY - height))
        let constrainedRect = NSRect(x: constrainedX, y: constrainedY, width: width, height: height)

        if animate {
          self.animator().setFrame(constrainedRect, display: true, animate: true)
        } else {
          self.setFrame(constrainedRect, display: true)
        }
        result(nil)
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Frame must be an array of 5 numbers", details: nil))
      }

    case "setMinimumSize":
      if let args = call.arguments as? [CGFloat], args.count == 2 {
        let width = args[0]
        let height = args[1]
        self.minSize = NSSize(width: width, height: height)
        result(nil)
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Minimum size must be an array of 2 numbers",
            details: nil))
      }

    case "setVisible":
      guard let visible = call.arguments as? Bool else {
        result(
          FlutterError(code: "INVALID_ARGUMENT", message: "Visible must be a boolean", details: nil)
        )
        return
      }

      self.setIsVisible(visible)
      self.animator().alphaValue = visible ? 1.0 : 0.0
      result(nil)

    case "orderFront":
      self.orderFront(nil)
      result(nil)

    case "removeDropTarget":
      let args = call.arguments as! [Any]
      let label = args[0] as? String
      if let target = self.dropTargets.first(where: { $0.label == label }) {
        target.removeFromSuperview()
        self.dropTargets = self.dropTargets.filter { $0.label != label }
      }
      result(nil)

    case "setDropTarget":
      let args = call.arguments as! [Any]
      let label = args[4] as! String
      let target = self.dropTargets.first { $0.label == label }

      let x = args[0] as! CGFloat
      let y = args[1] as! CGFloat
      let width = args[2] as! CGFloat
      let height = args[3] as! CGFloat

      let targetRect = NSRect(
        x: x,
        y: self.frame.height - y - height,
        width: width,
        height: height)

      // NSLog("self.frame \(self.frame)")
      if let target = target {
        // NSLog("updating target")
        target.frame = targetRect
      } else {
        // NSLog("adding new target")
        let newTarget = DropTarget(
          frame: targetRect,
          label: label,
          channel: channel
        )
        // newTarget.autoresizingMask = [.width, .height]
        newTarget.registerForDraggedTypes([
          NSPasteboard.PasteboardType.fileURL,
          NSPasteboard.PasteboardType.png,
          NSPasteboard.PasteboardType.tiff,
          NSPasteboard.PasteboardType.string,
          NSPasteboard.PasteboardType.URL,
        ])
        flutterViewController.view.addSubview(newTarget)
        self.dropTargets.append(newTarget)
        // NSLog("newTarget.frame \(newTarget.frame)")
      }
      result(nil)

    case "isVisible":
      result(self.isVisible)

    case "center":
      result([self.frame.midX, self.frame.midY])

    case "convertToPng":
      if let args = call.arguments as? [String], args.count == 2 {
        let inputPath = args[0]
        let outputPath = args[1]
        let success = convertImageToPNG(from: inputPath, to: outputPath)
        result(success)
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Convert to PNG must be an array of 2 strings",
            details: nil))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func convertImageToPNG(from path: String, to outputPath: String) -> Bool {
    // Load the image from the specified path
    guard let image = NSImage(contentsOfFile: path) else {
      print("Failed to load image from path: \(path)")
      return false
    }

    // Create a bitmap representation of the image
    guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData)
    else {
      print("Failed to create bitmap representation.")
      return false
    }

    // Convert the bitmap to PNG data
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
      print("Failed to convert image to PNG data.")
      return false
    }

    // Write the PNG data to the specified output path
    do {
      try pngData.write(to: URL(fileURLWithPath: outputPath))
      print("Image successfully converted and saved to \(outputPath)")
    } catch {
      print("Error saving PNG file: \(error.localizedDescription)")
    }
    return true
  }

  func getFileIcon(path: String, result: @escaping FlutterResult) {
    if let cachedIcon = self.iconCache.object(forKey: path as NSString) {
      result(self.iconToFlutterData(cachedIcon))
    } else {
      let icon = NSWorkspace.shared.icon(forFile: path)
      self.iconCache.setObject(icon, forKey: path as NSString)
      result(self.iconToFlutterData(icon))
    }
  }

  func iconToFlutterData(_ icon: NSImage) -> FlutterStandardTypedData {
    let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil)!
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    let pngData = bitmapRep.representation(using: .png, properties: [:])!
    return FlutterStandardTypedData(bytes: pngData)
  }

  func cleanup() {
    // clear the the temporary files that has the name dragged_image_*
    let tempDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let fileManager = FileManager.default
    do {
      let files = try fileManager.contentsOfDirectory(
        at: tempDirectoryURL, includingPropertiesForKeys: nil, options: [])
      for file in files {
        if file.lastPathComponent.starts(with: "dragged_image_") {
          try fileManager.removeItem(at: file)
        }
      }
    } catch {
      NSLog("Error removing temporary files: \(error)")
    }
  }

  func performDragSession(fileURLs: [String]) {
    // Create pasteboard items and dragging items for each file URL
    let draggingItems = fileURLs.enumerated().map { (index, fileURL) -> NSDraggingItem in
      let pasteboardItem = NSPasteboardItem()
      pasteboardItem.setString(fileURL, forType: .string)
      pasteboardItem.setDataProvider(dragSource, forTypes: [.fileURL])

      // TODO: add identifier to the pasteboard item to identify that it is from this app

      let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
      let dragFrame = NSRect(
        x: self.mouseLocationOutsideOfEventStream.x - 25,
        y: self.mouseLocationOutsideOfEventStream.y - 25, width: 50, height: 50)

      let icon = NSWorkspace.shared.icon(forFile: fileURL)

      switch index {
      case 0:
        draggingItem.setDraggingFrame(dragFrame, contents: icon)
      case 1...6:
        let rotationAngle = index == 1 ? 0 : CGFloat(index - 1) * 10 * (index % 2 == 0 ? 1 : -1)
        let rotatedImage = NSImage(size: icon.size, flipped: false) { rect in
          let context = NSGraphicsContext.current
          context?.saveGraphicsState()
          let transform = NSAffineTransform()
          transform.translateX(by: rect.width / 2, yBy: rect.height / 2)
          transform.rotate(byDegrees: rotationAngle)
          transform.translateX(by: -rect.width / 2, yBy: -rect.height / 2)
          transform.concat()
          icon.draw(
            in: rect, from: .zero, operation: .sourceOver, fraction: 1.0 - (CGFloat(index) * 0.05))
          context?.restoreGraphicsState()
          return true
        }
        draggingItem.setDraggingFrame(dragFrame, contents: rotatedImage)
      default:
        draggingItem.setDraggingFrame(
          NSRect(origin: dragFrame.origin, size: CGSize(width: 1, height: 1)), contents: nil)
      }

      return draggingItem
    }

    // Begin dragging session
    let draggingSession = dragSource.beginDraggingSession(
      with: draggingItems, event: NSApp.currentEvent!, source: dragSource)
    draggingSession.animatesToStartingPositionsOnCancelOrFail = true
  }

  func getCurrentScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens

    for screen in screens {
      if screen.frame.contains(mouseLocation) {
        return screen
      }
    }

    return nil
  }

  private func setupShakeDetector() {
    var positions: [CGPoint] = []
    var timestamps: [Date] = []
    let shakeThreshold = 10
    var isDragging = false
    var shakeDetected = false

    func watch(using closure: @escaping () -> Void) {
      var changeCount = 0

      Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        let pasteboard = NSPasteboard(name: .drag)
        if pasteboard.changeCount == changeCount { return }

        defer {
          changeCount = pasteboard.changeCount
        }

        closure()
      }
    }

    func checkMouseMovement() {
      let isLeftButtonDown = NSEvent.pressedMouseButtons & (1 << 0) != 0

      if !isLeftButtonDown || !isDragging {
        if shakeDetected {
          channel.invokeMethod("conclude", arguments: nil)
          shakeDetected = false
        }
        positions = []
        timestamps = []
        isDragging = false
        return
      }

      let currentPosition = NSEvent.mouseLocation
      let currentTimestamp = Date()

      if let lastTimestamp = timestamps.last,
        currentTimestamp.timeIntervalSince(lastTimestamp) > 1.0
      {
        positions.removeAll()
        timestamps.removeAll()
      }

      positions.append(currentPosition)
      timestamps.append(currentTimestamp)

      if positions.count > shakeThreshold {
        positions.removeFirst()
        timestamps.removeFirst()
      }

      // NSLog("positions: \(positions)")

      if detectShake() {
        handleShake(at: currentPosition)
      }
    }

    func detectShake() -> Bool {

      var directionChangesX = 0
      var directionChangesY = 0
      var isSpeedThresholdMet = false

      var lastDirectionX = 0
      var lastDirectionY = 0

      for i in 1..<positions.count {
        let dx = positions[i].x - positions[i - 1].x
        let dy = positions[i].y - positions[i - 1].y

        let currentDirectionX = dx == 0 ? 0 : (dx > 0 ? 1 : -1)
        let currentDirectionY = dy == 0 ? 0 : (dy > 0 ? 1 : -1)

        // Check for direction changes
        if i > 1 && currentDirectionX != 0 && currentDirectionX != lastDirectionX {
          directionChangesX += 1
        }

        if i > 1 && currentDirectionY != 0 && currentDirectionY != lastDirectionY {
          directionChangesY += 1
        }

        lastDirectionX = currentDirectionX != 0 ? currentDirectionX : lastDirectionX
        lastDirectionY = currentDirectionY != 0 ? currentDirectionY : lastDirectionY
      }

      // Check duration between first and final segment
      if positions.count >= 4 {
        let duration = CGFloat(timestamps.last!.timeIntervalSince(timestamps.first!))
        // NSLog("duration: \(duration)")
        if duration <= 1.0 {
          isSpeedThresholdMet = true
        } else {
          isSpeedThresholdMet = false
        }
      }

      // Detect shake if there are at least 5 direction changes in either axis and speed threshold is met
      return (directionChangesX >= 4 || directionChangesY >= 4) && isSpeedThresholdMet
    }

    func handleShake(at position: CGPoint) {
      shakeDetected = true
      channel.invokeMethod("shakeDetected", arguments: [position.x, position.y])
      // let wndWidth = self.frame.width
      // let wndHeight = self.frame.height

      // if self.isVisible {
      //   return
      // }
      // NSLog("Shake detected")
      // self.setIsVisible(true)
      // if let screen = getCurrentScreen() {
      //   let x = min(max(position.x - wndWidth / 2, screen.frame.minX), screen.frame.maxX - wndWidth)
      //   let cursorDistanceFromBottom = position.y - screen.frame.minY
      //   if cursorDistanceFromBottom < wndHeight + 24 {  // Adjust this value as needed
      //     self.setFrameOrigin(NSPoint(x: x, y: position.y + 24))
      //   } else {
      //     self.setFrameTopLeftPoint(NSPoint(x: x, y: position.y - 24))
      //   }
      // } else {
      //   self.setFrameTopLeftPoint(NSPoint(x: position.x - wndWidth / 2, y: position.y - 24))
      // }
      // self.makeKeyAndOrderFront(nil)
    }

    func getPasteboardCount(completion: @escaping (Int) -> Void) {
      DispatchQueue.main.async {
        let count = NSPasteboard(name: .drag).pasteboardItems?.count ?? 0
        completion(count)
      }
    }

    watch {
      isDragging = true
    }
    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
      checkMouseMovement()
    }
  }

  private func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    let menu = NSMenu()
    let menuItems = [
      ("Show", 1),
      ("Hide", 2),
      ("Quit", -1),
    ]

    for (title, tag) in menuItems {
      let item = NSMenuItem(title: title, action: #selector(menuItemClicked), keyEquivalent: "")
      item.target = self
      item.tag = tag
      menu.addItem(item)
    }
    statusItem.menu = menu
  }

  @objc func menuItemClicked(_ sender: NSMenuItem) {
    // Handle the menu item click based on the sender's tag or title
    if sender.tag == -1 {
      NSApplication.shared.terminate(nil)
    } else {
      channel.invokeMethod("menuItemClicked", arguments: sender.tag)
    }
  }
}

class DragSource: NSView, NSDraggingSource {
  private let channel: FlutterMethodChannel
  var session: NSDraggingSession?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func draggingSession(
    _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    self.session = session
    return [.copy, .move]
  }

  func draggingSession(
    _ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
  ) {
    NSLog("Drag ended at \(screenPoint)")
    channel.invokeMethod("draggingSessionEnded", arguments: operation.rawValue)
    self.session = nil
  }

}

// https://github.com/onmyway133/blog/issues/951
extension DragSource: NSPasteboardItemDataProvider {

  func getFileUrl(_ string: String?) -> NSURL? {
    if let string = string {
      // NSLog("string: \(string)")
      let url = NSURL(fileURLWithPath: string)
      if url.isFileURL {
        return url
      }
    }
    return nil
  }

  func pasteboard(
    _ pasteboard: NSPasteboard?, item: NSPasteboardItem,
    provideDataForType type: NSPasteboard.PasteboardType
  ) {
    // NSLog("provideDataForType: \(type)")
    switch type {

    case .fileURL:
      if let url = getFileUrl(item.string(forType: .string)) {
        // NSLog("url: \((url as URL))")
        // NSLog("url.dataRepresentation: \((url as URL).dataRepresentation)")
        // NSLog("url.path: \((url as URL).path)")
        // NSLog("url.standardized: \((url as URL).standardized.path)")
        // NSLog("url.standardized.path: \((url as URL).standardized.path.removingPercentEncoding!)")
        item.setData(url.dataRepresentation, forType: type)
      }

    default: break
    }
  }
}
