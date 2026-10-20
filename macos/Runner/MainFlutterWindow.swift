import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Paint the brand canvas (#0A0A0A) before Flutter's first frame so there
    // is no white flash (design/brand/splash/splash.md).
    let paperBackground = NSColor(red: 0.039, green: 0.039, blue: 0.039, alpha: 1)
    self.backgroundColor = paperBackground
    flutterViewController.backgroundColor = paperBackground
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.minSize = NSSize(width: 480, height: 560)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
