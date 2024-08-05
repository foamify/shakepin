import Cocoa
import FlutterMacOS
//import desktop_multi_window
import window_manager
import screen_retriever

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // See macos/Flutter/GeneratedPluginRegistrant.swift replace `registry` with `controller`
    // Based on https://github.com/pauli2406/iptv_player/commit/9da615c1ec567fb17cf83c62e24f38de50117bb6#diff-549803e7c2436a8249b5b60723d51961a9ab89083bef3bc714b1ed2344638628
    //FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
    //    controller.backgroundColor = .clear
    //    WindowManagerPlugin.register(with: controller.registrar(forPlugin: "WindowManagerPlugin"))
    //    ScreenRetrieverPlugin.register(with: controller.registrar(forPlugin: "ScreenRetrieverPlugin"))
    //}

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
      super.order(place, relativeTo: otherWin)
      hiddenWindowAtLaunch()
  }
}
