import Cocoa
import FlutterMacOS
import Firebase
import GoogleSignIn

@main
class AppDelegate: FlutterAppDelegate {
    override init() {
        super.init()
        FirebaseApp.configure()
    }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
      for url in urls {
        if GIDSignIn.sharedInstance.handle(url) {
          return
        }
      }
      super.application(application, open: urls)
    }

}
