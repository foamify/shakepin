import SwiftUI
import AppKit
import FlutterMacOS
import UniformTypeIdentifiers

struct UnifiedSettingsView: View {
  // General settings
  @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
  @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true

  // CLI Tools settings
  @AppStorage("ffmpegPath") private var ffmpegPath: String = ""
  @AppStorage("galleryDlPath") private var galleryDlPath: String = ""
  @AppStorage("gifskiPath") private var gifskiPath: String = ""
  @AppStorage("ytDlpPath") private var ytDlpPath: String = ""
  @AppStorage("imagemagickPath") private var imagemagickPath: String = ""
  @AppStorage("sevenZipPath") private var sevenZipPath: String = ""

  @State private var hoveredCard: String? = nil

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 20) {
        // Header
        VStack(spacing: 8) {
          HStack {
            Image(systemName: "gearshape.2.fill")
              .font(.system(size: 28, weight: .medium))
              .foregroundColor(.blue)

            Text("Settings")
              .font(.system(size: 32, weight: .bold, design: .rounded))
              .foregroundColor(.primary)

            Spacer()
          }

          Text("Customize your ShakePin experience")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)

        // General Settings Card
        SettingsCard(
          title: "General",
          icon: "person.circle.fill",
          iconColor: .blue,
          isHovered: hoveredCard == "general"
        ) {
          VStack(spacing: 16) {
            SettingsToggleRow(
              title: "Launch at Login",
              description: "Automatically start ShakePin when you log in",
              icon: "power.circle.fill",
              iconColor: .green,
              isOn: $launchAtLogin,
              onChange: { newValue in
                SettingsBridge.shared.notifySettingChanged(key: "launchAtLogin", value: newValue)
              }
            )
            .onChange(of: launchAtLogin) { newValue in
              print("[SETTINGS] launchAtLogin onChange triggered - new value: \(newValue)")
              NSLog("[SETTINGS] launchAtLogin onChange triggered - new value: %@", newValue ? "true" : "false")
              SettingsBridge.shared.notifySettingChanged(key: "launchAtLogin", value: newValue)
            }

            SettingsToggleRow(
              title: "Show Menu Bar Icon",
              description: "Display ShakePin icon in the menu bar",
              icon: "menubar.rectangle",
              iconColor: .blue,
              isOn: $showMenuBarIcon,
              onChange: { newValue in
                SettingsBridge.shared.notifySettingChanged(key: "showMenuBarIcon", value: newValue)
              }
            )
            .onChange(of: showMenuBarIcon) { newValue in
              print("[SETTINGS] showMenuBarIcon onChange triggered - new value: \(newValue)")
              NSLog("[SETTINGS] showMenuBarIcon onChange triggered - new value: %@", newValue ? "true" : "false")
              SettingsBridge.shared.notifySettingChanged(key: "showMenuBarIcon", value: newValue)
            }
          }
        }
        .onHover { isHovered in
          hoveredCard = isHovered ? "general" : nil
        }

        // CLI Tools Card
        SettingsCard(
          title: "CLI Tools",
          icon: "terminal.fill",
          iconColor: .purple,
          isHovered: hoveredCard == "cli"
        ) {
          VStack(spacing: 20) {
            // Video Processing Tools
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Image(systemName: "video.circle.fill")
                  .font(.system(size: 18))
                  .foregroundColor(.red)
                Text("Media Processing")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundColor(.primary)
                Spacer()
              }

              VStack(spacing: 12) {
                ToolPathRow(
                  toolName: "FFmpeg",
                  description: "Video and audio processing",
                  icon: "play.rectangle.fill",
                  iconColor: .red,
                  path: $ffmpegPath,
                  onPathChange: { newValue in
                    SettingsBridge.shared.notifySettingChanged(key: "ffmpegPath", value: newValue)
                  },
                  onBrowse: {
                    selectFile(for: "ffmpeg") { path in
                      ffmpegPath = path
                    }
                  }
                )

                ToolPathRow(
                  toolName: "Gifski",
                  description: "High-quality GIF encoder",
                  icon: "photo.stack.fill",
                  iconColor: .orange,
                  path: $gifskiPath,
                  onPathChange: { newValue in
                    SettingsBridge.shared.notifySettingChanged(key: "gifskiPath", value: newValue)
                  },
                  onBrowse: {
                    selectFile(for: "gifski") { path in
                      gifskiPath = path
                    }
                  }
                )

                // ImageMagick (image processing)
                ToolPathRow(
                  toolName: "ImageMagick",
                  description: "Image processing (magick)",
                  icon: "photo.fill.on.rectangle.fill",
                  iconColor: .pink,
                  path: $imagemagickPath,
                  onPathChange: { newValue in
                    SettingsBridge.shared.notifySettingChanged(key: "imagemagickPath", value: newValue)
                  },
                  onBrowse: {
                    selectFile(for: "magick") { path in
                      imagemagickPath = path
                    }
                  }
                )
              }
            }

            // Download Tools
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Image(systemName: "arrow.down.circle.fill")
                  .font(.system(size: 18))
                  .foregroundColor(.blue)
                Text("Download Tools")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundColor(.primary)
                Spacer()
              }

              VStack(spacing: 12) {
                ToolPathRow(
                  toolName: "gallery-dl",
                  description: "Download images and videos from galleries",
                  icon: "photo.on.rectangle.angled",
                  iconColor: .green,
                  path: $galleryDlPath,
                  onPathChange: { newValue in
                    SettingsBridge.shared.notifySettingChanged(key: "galleryDlPath", value: newValue)
                  },
                  onBrowse: {
                    selectFile(for: "gallery-dl") { path in
                      galleryDlPath = path
                    }
                  }
                )

                ToolPathRow(
                  toolName: "yt-dlp",
                  description: "Download videos from YouTube and other sites",
                  icon: "play.tv.fill",
                  iconColor: .red,
                  path: $ytDlpPath,
                  onPathChange: { newValue in
                    SettingsBridge.shared.notifySettingChanged(key: "ytDlpPath", value: newValue)
                  },
                  onBrowse: {
                    selectFile(for: "yt-dlp") { path in
                      ytDlpPath = path
                    }
                  }
                )
              }
            }

            // Other / Utility Tools
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Image(systemName: "wrench.fill")
                  .font(.system(size: 18))
                  .foregroundColor(.gray)
                Text("Other Tools")
                  .font(.system(size: 18, weight: .semibold))
                  .foregroundColor(.primary)
                Spacer()
              }

              VStack(spacing: 12) {
                ToolPathRow(
                  toolName: "7z",
                  description: "Archive utility (7-Zip)",
                  icon: "archivebox.fill",
                  iconColor: Color(red: 0.6, green: 0.4, blue: 0.2),
                  path: $sevenZipPath,
                  onPathChange: { newValue in
                    SettingsBridge.shared.notifySettingChanged(key: "sevenZipPath", value: newValue)
                  },
                  onBrowse: {
                    selectFile(for: "7z") { path in
                      sevenZipPath = path
                    }
                  }
                )
              }
            }

            HStack {
              Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(.blue)
              Text("Leave paths empty to use system defaults or auto-detected binaries.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
              Spacer()
            }
            .padding(.top, 8)
          }
        }
        .onHover { isHovered in
          hoveredCard = isHovered ? "cli" : nil
        }

        // Debug Card
        SettingsCard(
          title: "Debug & Maintenance",
          icon: "wrench.and.screwdriver.fill",
          iconColor: .orange,
          isHovered: hoveredCard == "debug"
        ) {
          VStack(spacing: 16) {
            HStack(spacing: 12) {
              DebugButton(
                title: "Show Log Files",
                description: "View application logs",
                icon: "doc.text.fill",
                iconColor: .blue,
                action: showLogFiles
              )

              DebugButton(
                title: "Clear Cache",
                description: "Free up storage space",
                icon: "trash.fill",
                iconColor: .red,
                action: clearAppCache
              )
            }

            HStack(spacing: 12) {
              DebugButton(
                title: "Export Debug Info",
                description: "Generate diagnostic report",
                icon: "square.and.arrow.up.fill",
                iconColor: .green,
                action: exportDebugInfo
              )

              DebugButton(
                title: "Reset Settings",
                description: "Restore default configuration",
                icon: "arrow.clockwise.circle.fill",
                iconColor: .orange,
                action: resetAllSettings,
                isDestructive: true
              )
            }
          }
        }
        .onHover { isHovered in
          hoveredCard = isHovered ? "debug" : nil
        }
      }
      .padding(20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func selectFile(for toolName: String, completion: @escaping (String) -> Void) {
    let panel = NSOpenPanel()
    panel.title = "Select \(toolName) binary"
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.unixExecutable, .executable]

    if panel.runModal() == .OK {
      if let url = panel.url {
        completion(url.path)
      }
    }
  }

  private func showLogFiles() {
    let logPaths = [
      "~/Library/Logs/ShakePin",
      "~/Library/Application Support/ShakePin",
      "/tmp/shakepin_logs"
    ]

    let alert = NSAlert()
    alert.messageText = "Log File Locations"
    alert.informativeText = "Logs may be found in these locations:\n\n" + logPaths.joined(separator: "\n")
    alert.addButton(withTitle: "Open Logs Folder")
    alert.addButton(withTitle: "Copy Paths")
    alert.addButton(withTitle: "Close")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      // Open logs folder
      let expandedPath = NSString(string: "~/Library/Logs").expandingTildeInPath
      NSWorkspace.shared.open(URL(fileURLWithPath: expandedPath))
    } else if response == .alertSecondButtonReturn {
      // Copy paths to clipboard
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(logPaths.joined(separator: "\n"), forType: .string)
    }
  }

  private func clearAppCache() {
    let alert = NSAlert()
    alert.messageText = "Clear App Cache"
    alert.informativeText = "This will clear temporary files and cached data. The app may need to restart."
    alert.addButton(withTitle: "Clear Cache")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning

    if alert.runModal() == .alertFirstButtonReturn {
      // Clear various cache directories
      let cachePaths = [
        "~/Library/Caches/com.shakepin.app",
        "~/Library/Application Support/ShakePin/cache",
        "/tmp/shakepin_temp"
      ]

      for path in cachePaths {
        let expandedPath = NSString(string: path).expandingTildeInPath
        try? FileManager.default.removeItem(atPath: expandedPath)
      }

      let successAlert = NSAlert()
      successAlert.messageText = "Cache Cleared"
      successAlert.informativeText = "App cache has been cleared successfully."
      successAlert.runModal()
    }
  }

  private func exportDebugInfo() {
    let panel = NSSavePanel()
    panel.title = "Export Debug Information"
    panel.nameFieldStringValue = "shakepin-debug-\(Date().timeIntervalSince1970).txt"
    panel.allowedContentTypes = [.plainText]

    if panel.runModal() == .OK {
      if let url = panel.url {
        let debugInfo = generateDebugInfo()
        try? debugInfo.write(to: url, atomically: true, encoding: .utf8)

        let alert = NSAlert()
        alert.messageText = "Debug Info Exported"
        alert.informativeText = "Debug information has been saved to \(url.path)"
        alert.runModal()
      }
    }
  }

  private func resetAllSettings() {
    let alert = NSAlert()
    alert.messageText = "Reset All Settings"
    alert.informativeText = "This will reset all settings to their default values. This action cannot be undone."
    alert.addButton(withTitle: "Reset")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .critical

    if alert.runModal() == .alertFirstButtonReturn {
      // Reset all UserDefaults
      let defaults = UserDefaults.standard
      let keys = ["launchAtLogin", "showMenuBarIcon", "theme", "ffmpegPath", "galleryDlPath", "gifskiPath", "ytDlpPath", "imagemagickPath", "sevenZipPath"]

      for key in keys {
        defaults.removeObject(forKey: key)
      }

      let successAlert = NSAlert()
      successAlert.messageText = "Settings Reset"
      successAlert.informativeText = "All settings have been reset to defaults. Please restart the app."
      successAlert.runModal()
    }
  }

  private func generateDebugInfo() -> String {
    var info = "ShakePin Debug Information\n"
    info += "Generated: \(Date())\n\n"

    // System info
    info += "System Information:\n"
    info += "macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
    info += "App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\n\n"

    // Settings
    info += "Current Settings:\n"
    let defaults = UserDefaults.standard
    info += "Launch at Login: \(defaults.bool(forKey: "launchAtLogin"))\n"
    info += "Show Menu Bar Icon: \(defaults.bool(forKey: "showMenuBarIcon"))\n"
    info += "Theme: \(defaults.string(forKey: "theme") ?? "System")\n"
    info += "FFmpeg Path: \(defaults.string(forKey: "ffmpegPath") ?? "(default)")\n"
    info += "Gifski Path: \(defaults.string(forKey: "gifskiPath") ?? "(default)")\n"
    info += "Gallery-dl Path: \(defaults.string(forKey: "galleryDlPath") ?? "(default)")\n"
    info += "YT-DLP Path: \(defaults.string(forKey: "ytDlpPath") ?? "(default)")\n"
    info += "ImageMagick Path: \(defaults.string(forKey: "imagemagickPath") ?? "(default)")\n"
    info += "7-Zip Path: \(defaults.string(forKey: "sevenZipPath") ?? "(default)")\n\n"

    // Tool availability
    info += "Tool Availability:\n"
    let tools = ["ffmpeg", "gifski", "gallery-dl", "yt-dlp"]
    for tool in tools {
      let process = Process()
      process.launchPath = "/usr/bin/which"
      process.arguments = [tool]
      process.launch()
      process.waitUntilExit()
      info += "\(tool): \(process.terminationStatus == 0 ? "Available" : "Not found")\n"
    }

    return info
  }
}

// Removed CLIToolsSettingsView and AdvancedSettingsView - functionality moved to UnifiedSettingsView

struct SettingsRootView: View {
  var body: some View {
    UnifiedSettingsView()
      .frame(minWidth: 640, minHeight: 480)
  }
}

// MARK: - Custom Components

struct SettingsCard<Content: View>: View {
  let title: String
  let icon: String
  let iconColor: Color
  let isHovered: Bool
  let content: Content

  init(title: String, icon: String, iconColor: Color, isHovered: Bool, @ViewBuilder content: () -> Content) {
    self.title = title
    self.icon = icon
    self.iconColor = iconColor
    self.isHovered = isHovered
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Card Header
      HStack {
        ZStack {
          Circle()
            .fill(LinearGradient(
              gradient: Gradient(colors: [iconColor.opacity(0.2), iconColor.opacity(0.1)]),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ))
            .frame(width: 32, height: 32)

          Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(iconColor)
        }

        Text(title)
           .font(.system(size: 20, weight: .bold))
           .foregroundColor(.primary)

        Spacer()
      }

      // Card Content
      content
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color(NSColor.controlBackgroundColor))
        .shadow(
          color: isHovered ? .black.opacity(0.15) : .black.opacity(0.08),
          radius: isHovered ? 8 : 4,
          x: 0,
          y: isHovered ? 4 : 2
        )
    )

  }
}

struct SettingsToggleRow: View {
  let title: String
  let description: String
  let icon: String
  let iconColor: Color
  @Binding var isOn: Bool
  let onChange: (Bool) -> Void

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(iconColor.opacity(0.15))
          .frame(width: 28, height: 28)

        Image(systemName: icon)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(iconColor)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.primary)

        Text(description)
          .font(.system(size: 13, weight: .regular))
          .foregroundColor(.secondary)
      }

      Spacer()

      Toggle("", isOn: $isOn)
        .toggleStyle(SwitchToggleStyle())
        .onChange(of: isOn) { newValue in
          onChange(newValue)
        }
    }
    .padding(.vertical, 4)
  }
}

struct ToolPathRow: View {
  let toolName: String
  let description: String
  let icon: String
  let iconColor: Color
  @Binding var path: String
  let onPathChange: (String) -> Void
  let onBrowse: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: icon)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(iconColor)

        Text(toolName)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Button("Install") {
          // Request Flutter to open the installation guide for this tool
          // Normalize common display names to the installation keys expected by Dart
          var normalized = toolName.lowercased()
          if toolName == "ImageMagick" {
            normalized = "imagemagick"
          } else if toolName == "7z" {
            normalized = "7z"
          } else if toolName == "gallery-dl" || toolName == "gallery_dl" {
            normalized = "gallery-dl"
          } else if toolName == "yt-dlp" || toolName == "ytdlp" || toolName == "yt_dlp" {
            normalized = "yt-dlp"
          } else {
            // fallback: replace underscores with dashes and use lowercased name
            normalized = normalized.replacingOccurrences(of: "_", with: "-")
          }
          SettingsBridge.shared.openInstallationGuide(toolName: normalized)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        
        Button("Browse") {
          onBrowse()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }

      Text(description)
        .font(.system(size: 12, weight: .regular))
        .foregroundColor(.secondary)

      TextField("Path to \(toolName.lowercased()) binary", text: $path)
         .textFieldStyle(.roundedBorder)
         .font(.system(size: 13, weight: .regular, design: .monospaced))
         .onChange(of: path) { newValue in
           onPathChange(newValue)
         }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
    )
  }
}

struct DebugButton: View {
  let title: String
  let description: String
  let icon: String
  let iconColor: Color
  let action: () -> Void
  let isDestructive: Bool

  init(title: String, description: String, icon: String, iconColor: Color, action: @escaping () -> Void, isDestructive: Bool = false) {
    self.title = title
    self.description = description
    self.icon = icon
    self.iconColor = iconColor
    self.action = action
    self.isDestructive = isDestructive
  }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack {
          Circle()
            .fill((isDestructive ? Color.red : iconColor).opacity(0.15))
            .frame(width: 40, height: 40)

          Image(systemName: icon)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(isDestructive ? .red : iconColor)
        }

        VStack(spacing: 2) {
          Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isDestructive ? .red : .primary)
            .multilineTextAlignment(.center)

          Text(description)
            .font(.system(size: 11, weight: .regular))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(12)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
      )
    }
    .buttonStyle(.plain)
    .onHover { isHovered in
      // Add subtle hover effect
    }
  }
}

class SettingsBridge {
  static let shared = SettingsBridge()
  private var channel: FlutterMethodChannel?

  func setChannel(_ channel: FlutterMethodChannel) {
    self.channel = channel
  }

  func notifySettingChanged(key: String, value: Any) {
    NSLog("[SETTINGS] SettingsBridge.notifySettingChanged called - key: %@, value: %@", key, String(describing: value))

    // Persist the setting to UserDefaults immediately so it is available next launch
    self.setSetting(key: key, value: value)
    NSLog("[SETTINGS] SettingsBridge.notifySettingChanged persisted - key: %@, value: %@", key, String(describing: value))

    // Find the MainFlutterWindow instance
    if let mainWindow = NSApp.windows.first(where: { $0 is MainFlutterWindow }) as? MainFlutterWindow {
      NSLog("[SETTINGS] Found MainFlutterWindow, calling handleSettingChangeFromBridge")
      mainWindow.handleSettingChangeFromBridge(key: key, value: value)

      // Also notify Flutter side through the main window's flutter controller
      // Use the correct settings channel name so Dart receives the notification
      NSLog("[SETTINGS] Found FlutterViewController, invoking settingChanged method on click.shakepin.macos/settings channel")
      let channel = FlutterMethodChannel(name: "click.shakepin.macos/settings", binaryMessenger: mainWindow.flutterViewController.engine.binaryMessenger)
      channel.invokeMethod("settingChanged", arguments: ["key": key, "value": value])
    } else {
      NSLog("[SETTINGS] Could not find MainFlutterWindow")
    }
  }

  /// Ask Flutter to open the installation guide for a given CLI tool.
  /// This will invoke the `openInstall` method on the settings method channel
  /// with a single String argument (the tool identifier, e.g. "ffmpeg", "imagemagick", "7z").
  func openInstallationGuide(toolName: String) {
    NSLog("[SETTINGS] openInstallationGuide called - tool: %@", toolName)
    // Normalize common tool identifiers to match Dart's CliToolHelper keys
    var normalized = toolName.lowercased()
    // Map macOS binary names to the installation keys used by CliToolHelper
    if normalized == "magick" || normalized == "convert" || normalized == "magick.exe" {
      normalized = "imagemagick"
    } else if normalized == "7zz" {
      // some systems use 7zz as the executable; normalize to 7z key
      normalized = "7z"
    } else if normalized == "gallery-dl" || normalized == "gallery_dl" {
      normalized = "gallery-dl"
    } else if normalized == "ytdlp" || normalized == "yt_dlp" {
      normalized = "yt-dlp"
    }
    // Find MainFlutterWindow to access a Flutter binary messenger
    if let mainWindow = NSApp.windows.first(where: { $0 is MainFlutterWindow }) as? MainFlutterWindow {
      let channel = FlutterMethodChannel(name: "click.shakepin.macos/settings", binaryMessenger: mainWindow.flutterViewController.engine.binaryMessenger)
      channel.invokeMethod("openInstall", arguments: normalized)
      NSLog("[SETTINGS] openInstallationGuide invoked Flutter method 'openInstall' with arg: %@", normalized)
    } else {
      NSLog("[SETTINGS] Could not find MainFlutterWindow for openInstallationGuide")
    }
  }

  func getSetting(key: String) -> Any? {
    let value = UserDefaults.standard.object(forKey: key)
    NSLog("[SETTINGS] SettingsBridge.getSetting - key: %@, value: %@", key, String(describing: value))
    return value
  }

  func setSetting(key: String, value: Any) {
    NSLog("[SETTINGS] SettingsBridge.setSetting - key: %@, value: %@", key, String(describing: value))
    UserDefaults.standard.set(value, forKey: key)
    NSLog("[SETTINGS] SettingsBridge.setSetting - value stored in UserDefaults")
  }
}

final class SettingsHostingController: NSHostingController<SettingsRootView> {
  init() {
    super.init(rootView: SettingsRootView())
  }
  @objc required dynamic init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    rootView = SettingsRootView()
  }
}
