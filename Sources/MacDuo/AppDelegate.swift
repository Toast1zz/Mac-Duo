import AppKit
import CoreGraphics

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var controller: LidController?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.geometry.notice("launched, screen recording granted: \(CGPreflightScreenCaptureAccess())")
        let preferences = Preferences.shared
        let controller = LidController(preferences: preferences)
        self.controller = controller
        statusItemController = StatusItemController(controller: controller, preferences: preferences)
        controller.start()
        // Asking puts the app in the Screen Recording list, so it can be
        // switched on there. Only pointing at the pane leaves the list without
        // it, most of all after a rebuild changes the signature.
        if controller.isSensorAvailable, !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }
}
