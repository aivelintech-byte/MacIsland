import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: IslandPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = IslandPanel()
        panel?.orderFrontRegardless()
        AutoUpdater().checkForUpdates()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
