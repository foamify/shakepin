import AppKit
import Cocoa
import Compression
import FlutterMacOS

enum ImageFormat: Int {
  case png, jpeg, tiff, webp
}

class MainFlutterWindow: NSWindow {

  var statusItem: NSStatusItem!
  var channel: FlutterMethodChannel!
  var flutterViewController: FlutterViewController!
  var dropTargets: [DropTarget] = []
  var dragSource: DragSource!
  var initialized = false
  var compressing = false

  var iconCache = NSCache<NSString, NSImage>()
  var popover: NSPopover?

  var dropdownChannel: FlutterMethodChannel!
  var dropdownButtons: [String: NSPopUpButton] = [:]
  var dropdownMenu: NSMenu?

  var dragStarted = false

  private var currentProcess: Process?
  private var currentOutputPipe: Pipe?
  private var currentErrorPipe: Pipe?
  private var currentTimeoutTimer: DispatchSourceTimer?

  private var processHandler: ProcessHandler!
  private var shiftKeyCheckEnabled = true  // Add this property

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

    setupNativeDropdownChannel()

    setupWindow(flutterViewController)

    setupShakeDetector()

    setupMenuBar()

    processHandler = ProcessHandler(channel: channel)

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

  override var isMainWindow: Bool {
    return true
  }

  override var canBecomeKey: Bool {
    return true
  }

  override var canBecomeMain: Bool {
    return true
  }

  func setupNativeDropdownChannel() {
    dropdownChannel = FlutterMethodChannel(
      name: "com.damywise.flutter_macos_native_dropdown/channel",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    dropdownChannel.setMethodCallHandler(handleNativeDropdownMethodCall)
  }

  func handleNativeDropdownMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "updateNativeDropdown" {
      guard let args = call.arguments as? [String: Any],
        let items = args["items"] as? [[String: Any]],
        let x = args["x"] as? CGFloat,
        let y = args["y"] as? CGFloat,
        let width = args["width"] as? CGFloat,
        let height = args["height"] as? CGFloat,
        let selectedIndex = args["selectedIndex"] as? Int,
        let dropdownId = args["dropdownId"] as? String,
        let enabled = args["enabled"] as? Bool,
        let remove = args["remove"] as? Bool,
        let pullsDown = args["pullsDown"] as? Bool
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "Invalid arguments for updateNativeDropdown",
            details: nil))
        return
      }

      if remove {
        if let button = dropdownButtons[dropdownId] {
          button.removeFromSuperview()
          dropdownButtons.removeValue(forKey: dropdownId)
        }
        result(nil)
        return
      }

      let button: NSPopUpButton
      if let existingButton = dropdownButtons[dropdownId] {
        button = existingButton
      } else {
        button = NSPopUpButton.init(popUpMenu: dropdownMenu ?? NSMenu(), target: nil, action: nil)
        button.bezelStyle = .rounded
        button.target = self
        button.action = #selector(handlePopUpButtonAction(_:))
        button.isBordered = false
        button.alphaValue = 0
        flutterViewController.view.addSubview(button)
        dropdownButtons[dropdownId] = button
      }

      // Update frame
      let flutterViewHeight = flutterViewController.view.frame.height
      let buttonFrame = NSRect(
        x: x, y: flutterViewHeight - y - height, width: width, height: height)
      button.frame = buttonFrame

      button.menu!.autoenablesItems = false

      if pullsDown {
        button.pullsDown = true
      }

      // Update items
      button.removeAllItems()
      for item in items {
        guard let title = item["title"] as? String,
          let enabled = item["enabled"] as? Bool
        else { continue }
        button.menu?.addItem(withTitle: title, action: nil, keyEquivalent: "")
        button.menu?.items.last?.isEnabled = enabled
      }

      // Update selection and state
      if selectedIndex >= 0 && selectedIndex < items.count {
        button.selectItem(at: selectedIndex)
      } 
      button.isEnabled = enabled

      result(nil)
    } else {
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func handlePopUpButtonAction(_ sender: NSPopUpButton) {
    guard let dropdownId = dropdownButtons.first(where: { $0.value === sender })?.key else {
      return
    }
    dropdownChannel.invokeMethod(
      "onDropdownMenuSelected",
      arguments: [
        "id": dropdownId,
        "index": sender.indexOfSelectedItem,
      ])
  }

  @objc private func handleMenuSelection(_ sender: NSMenuItem) {
    NSLog("Menu item selected: \(sender.title)")
    NSLog("dropdownId: \(sender.representedObject)")
    if let dropdownId = sender.representedObject as? String {
      dropdownChannel.invokeMethod(
        "onDropdownMenuSelected",
        arguments: [
          "id": dropdownId,
          "index": sender.tag,
        ]
      )
    }
  }

  func setupWindow(_ flutterViewController: FlutterViewController) {

    self.contentViewController = flutterViewController
    flutterViewController.backgroundColor = .clear

    self.isOpaque = false
    self.backgroundColor = .clear

    // Remove title bar and make it transparent
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    // Remove the top border/highlight
    self.styleMask.remove(.titled)
    // self.appearance = NSAppearance(named: .vibrantDark)

    // Hide standard window buttons
    self.standardWindowButton(.closeButton)?.isHidden = true
    self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    self.standardWindowButton(.zoomButton)?.isHidden = true

    self.styleMask.insert(.fullSizeContentView)

    // If you want to make the window draggable from any point
    // self.isMovableByWindowBackground = true

    // self.contentView?.layer?.cornerRadius = 12
    // self.contentView?.layer?.masksToBounds = true
    // Add corner radius to the window
    self.contentView?.wantsLayer = true
    self.contentView?.layer?.cornerRadius = 32
    self.contentView?.layer?.masksToBounds = true

    let effectView = NSVisualEffectView()
    effectView.autoresizingMask = [.width, .height]
    effectView.blendingMode = .behindWindow
    effectView.material = .menu
    effectView.state = .active
    effectView.frame = flutterViewController.view.bounds
    effectView.wantsLayer = true
    effectView.layer?.cornerRadius = 16
    effectView.layer?.masksToBounds = true

    self.contentView?.addSubview(
      effectView, positioned: .below, relativeTo: flutterViewController.view)

    // flutterViewController.view.layer?.borderWidth = 1
    // flutterViewController.view.layer?.borderColor = NSColor.systemGray.cgColor.copy(alpha: 0.5)

    // self.standardWindowButton(.closeButton)?.isHidden = true
    // self.standardWindowButton(.miniaturizeButton)?.isHidden = true
    // self.standardWindowButton(.zoomButton)?.isHidden = true

    // self.titleVisibility = .hidden
    // self.titlebarAppearsTransparent = true
    self.level = .floating
    // self.hasShadow = true

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

    case "convertImage":
      if let args = call.arguments as? [Any], args.count == 2,
        let inputPath = args[0] as? String,
        let formatIndex = args[1] as? Int,
        let format = ImageFormat(rawValue: formatIndex)
      {
        if let outputPath = convertImage(from: inputPath, to: format) {
          result(outputPath)
        } else {
          result(
            FlutterError(
              code: "CONVERSION_FAILED", message: "Failed to convert image", details: nil))
        }
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Invalid arguments for convertImage", details: nil))
      }

    case "showPopover":
      guard let args = call.arguments as? [Any],
        let content = args[0] as? String,
        let edgeIndex = args[1] as? Int
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "Invalid arguments for showPopover",
            details: nil))
        return
      }

      let edge: NSRectEdge =
        switch edgeIndex {
        case 0: .minX  // left
        case 1: .maxX  // right
        case 2: .maxY  // top
        case 3: .minY  // bottom
        default: .minX  // default to left
        }

      showPopover(content: content, edge: edge)
      result(nil)

    case "hidePopover":
      hidePopover()
      result(nil)

    case "getAppVersion":
      result(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")

    case "shareXFiles":
      if let fileURLs = call.arguments as? [String] {
        shareXFiles(fileURLs: fileURLs, result: result)
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT", message: "Invalid arguments for shareXFiles", details: nil))
      }
    case "startProcess":
      if let args = call.arguments as? [String: Any],
        let command = args["command"] as? String,
        let arguments = args["arguments"] as? [String]
      {
        startProcess(command: command, arguments: arguments, result: result)
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Invalid arguments for startProcess. Expected command and arguments",
            details: nil))
      }
    case "startDragging":
      startDragging()
      result(nil)

    case "cancelProcess":
      NSLog("Received cancelProcess")
      cleanupProcess()
      result(true)

    case "isProcessRunning":
      result(processHandler.isProcessRunning())

    case "setShiftKeyCheckEnabled":
      if let enabled = call.arguments as? Bool {
        shiftKeyCheckEnabled = enabled
        result(nil)
      } else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Argument must be a boolean",
            details: nil))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func startDragging() {
    DispatchQueue.main.async {
      if let currentEvent = self.currentEvent {
        self.performDrag(with: currentEvent)
      }
    }
  }

  private func startProcess(command: String, arguments: [String], result: @escaping FlutterResult) {
    processHandler.startProcess(command: command, arguments: arguments, result: result)
  }

  private func cleanupProcess() {
    processHandler.cleanup()
  }

  func convertImage(from path: String, to format: ImageFormat) -> String? {
    guard let image = NSImage(contentsOfFile: path) else {
      print("Failed to load image from path: \(path)")
      return nil
    }

    guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData)
    else {
      print("Failed to create bitmap representation.")
      return nil
    }

    let fileType: NSBitmapImageRep.FileType
    let fileExtension: String

    switch format {
    case .png:
      fileType = .png
      fileExtension = "png"
    case .jpeg:
      fileType = .jpeg
      fileExtension = "jpg"
    case .tiff:
      fileType = .tiff
      fileExtension = "tiff"
    // case .gif:
    //   fileType = .gif
    //   fileExtension = "gif"
    // case .bmp:
    //   fileType = .bmp
    //   fileExtension = "bmp"
    // case .ico:
    //   // NSBitmapImageRep doesn't support ICO directly, so we'll use PNG as a fallback
    //   fileType = .png
    //   fileExtension = "ico"
    case .webp:
      // NSBitmapImageRep doesn't support WebP, so we'll use PNG as a fallback
      fileType = .png
      fileExtension = "webp"
    }

    guard let imageData = bitmap.representation(using: fileType, properties: [:]) else {
      print("Failed to convert image data.")
      return nil
    }

    let fileName = "temp_file_\(UUID().uuidString).\(fileExtension)"
    let tempDirectory = FileManager.default.temporaryDirectory
    let outputURL = tempDirectory.appendingPathComponent(fileName)

    do {
      try imageData.write(to: outputURL)
      print("Image successfully converted and saved to \(outputURL.path)")
      return outputURL.path
    } catch {
      print("Error saving converted image: \(error.localizedDescription)")
      return nil
    }
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
    // Clear the temporary files that have the name temp_file_*
    let fileManager = FileManager.default
    let tempDirectoryURL = fileManager.temporaryDirectory
    do {
      let files = try fileManager.contentsOfDirectory(
        at: tempDirectoryURL, includingPropertiesForKeys: nil, options: [])
      for file in files {
        if file.lastPathComponent.starts(with: "temp_file_") {
          try fileManager.removeItem(at: file)
        }
      }
    } catch {
      NSLog("Error removing temporary files: \(error)")
    }
  }

  func performDragSession(fileURLs: [String]) {
    // Optimize icon loading
    let icons = fileURLs.map { fileURL -> NSImage in
      if let cachedIcon = self.iconCache.object(forKey: fileURL as NSString) {
        return cachedIcon
      } else {
        let icon = NSWorkspace.shared.icon(forFile: fileURL)
        self.iconCache.setObject(icon, forKey: fileURL as NSString)
        return icon
      }
    }

    // Set drag data in DragSource
    dragSource.setDragData([
      "fileURLs": fileURLs,
      "currentIndex": 0,
    ])

    // Create dragging items
    let draggingItems = fileURLs.enumerated().map { (index, fileURL) -> NSDraggingItem in
      let pasteboardItem = NSPasteboardItem()
      pasteboardItem.setString(fileURL, forType: .string)
      pasteboardItem.setDataProvider(dragSource, forTypes: [.fileURL])

      let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
      let dragFrame = NSRect(
        x: self.mouseLocationOutsideOfEventStream.x - 25,
        y: self.mouseLocationOutsideOfEventStream.y - 25, width: 50, height: 50)

      let icon = icons[index]

      if index <= 6 {
        if index > 0 {
          let rotationAngle = CGFloat(index - 1) * 10 * (index % 2 == 0 ? 1 : -1)
          let rotatedImage = icon.rotated(by: rotationAngle, opacity: 1.0 - (CGFloat(index) * 0.05))
          draggingItem.setDraggingFrame(dragFrame, contents: rotatedImage)
        } else {
          draggingItem.setDraggingFrame(dragFrame, contents: icon)
        }
      } else {
        draggingItem.setDraggingFrame(
          NSRect(origin: dragFrame.origin, size: CGSize(width: 1, height: 1)), contents: nil)
      }

      return draggingItem
    }

    // Begin dragging session
    dragSource.beginDraggingSession(
      with: draggingItems, event: NSApp.currentEvent!, source: dragSource)
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

  private func getPasteboardCount(completion: @escaping (Int) -> Void) {
    DispatchQueue.main.async {
      let pasteboard = NSPasteboard(name: .drag)
      let count = pasteboard.pasteboardItems?.count ?? 0
      completion(count)
    }
  }

  private func setupShakeDetector() {
    var globalMonitor: Any?
    var mouseDownMonitor: Any?
    var mouseUpMonitor: Any?
    var initialChangeCount = 0
    var isDragging = false
    var positions: [CGPoint] = []
    var timestamps: [Date] = []
    let shakeThreshold = 4  // Changed from 6 to 4 direction changes
    let timeWindow: TimeInterval = 1  // Time window to detect shake
    let minVelocity: CGFloat = 200  // Pixels per second

    // Monitor mouse down
    mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
      let pasteboard = NSPasteboard(name: .drag)
      initialChangeCount = pasteboard.changeCount
      positions.removeAll()
      timestamps.removeAll()
      isDragging = true
      self.dragStarted = false
      // NSLog("MouseDown - Initial drag pasteboard changeCount: \(initialChangeCount)")
    }

    // Monitor drag movement
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { event in
      guard isDragging else { return }

      let pasteboard = NSPasteboard(name: .drag)
      let currentChangeCount = pasteboard.changeCount

      // Only process if we're actually dragging something
      if currentChangeCount != initialChangeCount {
        if !self.dragStarted {
          self.channel.invokeMethod("dragStart", arguments: nil)
          self.dragStarted = true
        }

        let currentPos = NSEvent.mouseLocation
        let currentTime = Date()

        // Check if shift key is pressed
        if self.shiftKeyCheckEnabled && event.modifierFlags.contains(.shift) {
          self.handleShake(at: currentPos)
          return
        }

        positions.append(currentPos)
        timestamps.append(currentTime)

        // Keep only recent movements
        while timestamps.count > 1 && currentTime.timeIntervalSince(timestamps[0]) > timeWindow {
          positions.removeFirst()
          timestamps.removeFirst()
        }

        // Check for shake pattern
        if self.detectShake(
          positions: positions, timestamps: timestamps,
          threshold: shakeThreshold, minVelocity: minVelocity)
        {
          self.handleShake(at: currentPos)
        }
      }
    }

    // Monitor mouse up
    mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { _ in
      self.dragStarted = false
      let pasteboard = NSPasteboard(name: .drag)
      let currentChangeCount = pasteboard.changeCount
      if currentChangeCount != initialChangeCount {
        isDragging = false
        positions.removeAll()
        timestamps.removeAll()
        self.channel.invokeMethod("dragConclude", arguments: nil)
      }
    }
  }

  private func detectShake(
    positions: [CGPoint], timestamps: [Date],
    threshold: Int, minVelocity: CGFloat
  ) -> Bool {
    guard positions.count > 2 else { return false }

    var horizontalChanges = 0
    var verticalChanges = 0
    var lastHorizontalDirection: Int = 0  // -1 for left, 1 for right
    var lastVerticalDirection: Int = 0  // -1 for down, 1 for up
    var totalDistance: CGFloat = 0

    // Calculate direction changes and velocity
    for i in 1..<positions.count {
      let dx = positions[i].x - positions[i - 1].x
      let dy = positions[i].y - positions[i - 1].y

      let currentHorizontalDirection = dx == 0 ? 0 : dx > 0 ? 1 : -1
      let currentVerticalDirection = dy == 0 ? 0 : dy > 0 ? 1 : -1

      totalDistance += sqrt(dx * dx + dy * dy)

      if lastHorizontalDirection != 0 && currentHorizontalDirection != 0
        && currentHorizontalDirection != lastHorizontalDirection
      {
        horizontalChanges += 1
      }

      if lastVerticalDirection != 0 && currentVerticalDirection != 0
        && currentVerticalDirection != lastVerticalDirection
      {
        verticalChanges += 1
      }

      if currentHorizontalDirection != 0 {
        lastHorizontalDirection = currentHorizontalDirection
      }
      if currentVerticalDirection != 0 {
        lastVerticalDirection = currentVerticalDirection
      }
    }

    // Calculate velocity
    let duration = timestamps.last!.timeIntervalSince(timestamps.first!)
    let velocity = CGFloat(totalDistance) / CGFloat(duration)

    // Consider shake detected if either horizontal or vertical changes exceed threshold
    return (horizontalChanges >= threshold || verticalChanges >= threshold)
      && velocity >= minVelocity
  }

  private func handleShake(at position: CGPoint) {
    channel.invokeMethod("shakeDetected", arguments: [position.x, position.y])
  }

  private func setupMenuBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    let menu = NSMenu()
    let menuItems = [
      ("Show", 1),
      ("Hide", 2),
      ("About Shakepin", 3),
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

  func showPopover(content: String, edge: NSRectEdge) {
    if popover == nil {
      popover = NSPopover()
    }

    if popover?.isShown == true {
      // If popover is already shown, update its content
      if let existingContentView = popover?.contentViewController?.view.subviews.first
        as? NSTextField
      {
        existingContentView.stringValue = content
      }
    } else {
      // If popover is not shown, create and show it
      let contentViewController = NSViewController()
      let contentView = NSTextField(labelWithString: content)
      contentView.drawsBackground = false
      contentView.lineBreakMode = .byWordWrapping
      contentView.preferredMaxLayoutWidth = 200  // Adjust this value as needed

      let paddingView = NSView()
      paddingView.addSubview(contentView)
      contentView.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        contentView.topAnchor.constraint(equalTo: paddingView.topAnchor, constant: 10),
        contentView.leadingAnchor.constraint(equalTo: paddingView.leadingAnchor, constant: 10),
        contentView.trailingAnchor.constraint(equalTo: paddingView.trailingAnchor, constant: -10),
        contentView.bottomAnchor.constraint(equalTo: paddingView.bottomAnchor, constant: -10),
      ])

      contentViewController.view = paddingView

      popover?.contentViewController = contentViewController
      popover?.behavior = .transient
      popover?.animates = true

      let mouseLocation = NSEvent.mouseLocation
      let windowPoint = self.convertPoint(fromScreen: mouseLocation)
      let viewPoint = self.contentView?.convert(windowPoint, from: nil) ?? windowPoint

      popover?.show(
        relativeTo: NSRect(origin: mouseLocation, size: .zero), of: self.contentView!,
        preferredEdge: edge)
    }
  }

  func hidePopover() {
    popover?.close()
  }

  func shareXFiles(fileURLs: [String], result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      let urls = fileURLs.map { URL(fileURLWithPath: $0) }
      let picker = NSSharingServicePicker(items: urls)
      picker.delegate = ShareSuccessDelegate(result: result).keep()

      if let contentView = self.contentView {
        picker.show(relativeTo: self.frame, of: self.contentView!, preferredEdge: .minY)
      } else {
        result(
          FlutterError(code: "SHARE_ERROR", message: "Unable to show share picker", details: nil))
      }
    }
  }
}

class DragSource: NSView, NSDraggingSource {
  private let channel: FlutterMethodChannel
  var session: NSDraggingSession?
  var dragData: [String: Any] = [:]

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

  func setDragData(_ data: [String: Any]) {
    self.dragData = data
  }
}

// Update the NSPasteboardItemDataProvider extension
extension DragSource: NSPasteboardItemDataProvider {
  func pasteboard(
    _ pasteboard: NSPasteboard?, item: NSPasteboardItem,
    provideDataForType type: NSPasteboard.PasteboardType
  ) {
    if type == .fileURL,
      let fileURLs = dragData["fileURLs"] as? [String],
      let index = dragData["currentIndex"] as? Int,
      index < fileURLs.count
    {
      let fileURL = fileURLs[index]
      let url = NSURL(fileURLWithPath: fileURL)
      item.setData(url.dataRepresentation, forType: type)

      // Increment the index for the next item
      dragData["currentIndex"] = index + 1
    }
  }
}

// Add this extension to NSImage for efficient rotation
extension NSImage {
  func rotated(by angle: CGFloat, opacity: CGFloat) -> NSImage {
    let rotatedImage = NSImage(size: self.size, flipped: false) { rect in
      let context = NSGraphicsContext.current
      context?.saveGraphicsState()
      let transform = NSAffineTransform()
      transform.translateX(by: rect.width / 2, yBy: rect.height / 2)
      transform.rotate(byDegrees: angle)
      transform.translateX(by: -rect.width / 2, yBy: -rect.height / 2)
      transform.concat()
      self.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity)
      context?.restoreGraphicsState()
      return true
    }
    return rotatedImage
  }
}

class ShareSuccessDelegate: NSObject, NSSharingServicePickerDelegate {
  private var result: FlutterResult
  private var keepSelf: (() -> Void)?

  init(result: @escaping FlutterResult) {
    self.result = result
  }

  public func keep() -> Self {
    self.keepSelf = { _ = self }
    return self
  }

  public func sharingServicePicker(
    _ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?
  ) {
    result(service != nil ? service!.title : "")
    self.keepSelf = nil
  }
}

class ProcessHandler {
  private let channel: FlutterMethodChannel
  private var currentProcess: Process?
  private var currentOutputPipe: Pipe?
  private var currentErrorPipe: Pipe?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    NSLog("ProcessHandler initialized")
  }

  func startProcess(command: String, arguments: [String], result: @escaping FlutterResult) {
    NSLog("Starting process with command: \(command) and arguments: \(arguments)")
    cleanup()

    let process = Process()
    let outputPipe = Pipe()
    let errorPipe = Pipe()

    self.currentProcess = process
    self.currentOutputPipe = outputPipe
    self.currentErrorPipe = errorPipe

    let fullCommand = ([command] + arguments).joined(separator: " ")
    NSLog("Full command to execute: \(fullCommand)")

    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = ["-l", "-c", fullCommand]
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    // Create output storage
    var collectedOutput = Data()
    var collectedError = Data()

    // Setup pipe handling
    outputPipe.fileHandleForReading.readabilityHandler = { [weak channel = self.channel] handle in
      let data = handle.availableData
      if !data.isEmpty {
        collectedOutput.append(data)
        if let output = String(data: data, encoding: .utf8) {
          // NSLog("Process output: \(output)")
          DispatchQueue.main.async {
            channel?.invokeMethod("cliOutput", arguments: output)
          }
        }
      }
    }

    errorPipe.fileHandleForReading.readabilityHandler = { [weak channel = self.channel] handle in
      let data = handle.availableData
      if !data.isEmpty {
        collectedError.append(data)
        if let error = String(data: data, encoding: .utf8) {
          // NSLog("Process error: \(error)")
          DispatchQueue.main.async {
            channel?.invokeMethod("cliError", arguments: error)
          }
        }
      }
    }

    process.terminationHandler = { process in
      NSLog("Process terminated with status: \(process.terminationStatus)")
      self.cleanup()
      DispatchQueue.main.async {
        result([
          "exitCode": process.terminationStatus,
          "output": String(data: collectedOutput, encoding: .utf8) ?? "",
          "error": String(data: collectedError, encoding: .utf8) ?? "",
        ])
      }
    }

    do {
      NSLog("Attempting to launch process")
      process.launch()

      let pgid = process.processIdentifier
      let pgidResult = setpgid(pgid, pgid)
      NSLog("Process launched - PID: \(pgid), PGID set result: \(pgidResult)")

    } catch {
      NSLog("Failed to launch process: \(error.localizedDescription)")
      self.cleanup()
      result(
        FlutterError(
          code: "PROCESS_ERROR",
          message: error.localizedDescription,
          details: nil
        ))
    }
  }

  func cleanup() {
    NSLog("Starting process cleanup")

    if let process = currentProcess {
      let pgid = process.processIdentifier
      NSLog("Found active process with PID: \(pgid)")

      // Kill process group
      let killResult = killpg(pgid, SIGKILL)
      NSLog("killpg result: \(killResult)")

      process.terminate()
      NSLog("Process terminate() called")

      // Clean up pipes
      currentOutputPipe?.fileHandleForReading.readabilityHandler = nil
      currentErrorPipe?.fileHandleForReading.readabilityHandler = nil
    } else {
      NSLog("No active process found during cleanup")
    }

    currentProcess = nil
    currentOutputPipe = nil
    currentErrorPipe = nil
    NSLog("Process cleanup completed - all references cleared")
  }

  func isProcessRunning() -> Bool {
    return currentProcess != nil
  }
}
