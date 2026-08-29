import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static func disableWindowRestorationDefaults() {
    UserDefaults.standard.set(true, forKey: "ApplePersistenceIgnoreState")
    UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
  }

  override init() {
    super.init()
    Self.disableWindowRestorationDefaults()
  }

  override func awakeFromNib() {
    super.awakeFromNib()
    Self.disableWindowRestorationDefaults()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  func applicationShouldSaveApplicationState(_ app: NSApplication) -> Bool {
    return false
  }

  func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    Self.disableWindowRestorationDefaults()
  }
}
