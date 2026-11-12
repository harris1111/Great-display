import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(pane: SettingsPane? = nil) {
        if let pane { SettingsNavigation.shared.selection = pane }
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Great Display Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            // Sidebar and device bar run up under a transparent title bar.
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.setContentSize(NSSize(width: 1000, height: 760))
            window.contentMinSize = NSSize(width: 880, height: 620)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.setFrameAutosaveName("GreatDisplaySettings")
            if !window.setFrameUsingName("GreatDisplaySettings") { window.center() }
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
