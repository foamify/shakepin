import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }
  
  // Add a Settings menu item under the app menu if not present and wire to MainFlutterWindow
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if let mainMenu = NSApp.mainMenu, let appMenuItem = mainMenu.items.first, let appSubmenu = appMenuItem.submenu {
      // Check if Settings exists
      let hasSettings = appSubmenu.items.contains { $0.action == #selector(openSettings) }
      if !hasSettings {
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        // Insert after About
        let insertIndex = min(1, appSubmenu.items.count)
        appSubmenu.insertItem(settingsItem, at: insertIndex)
      }
    }
  }

  @objc func openSettings() {
    if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) as? MainFlutterWindow {
      window.showSettingsWindow()
    }
  }
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
