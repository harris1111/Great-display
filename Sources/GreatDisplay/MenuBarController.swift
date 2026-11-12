import AppKit
import SwiftUI
import Combine
import GDCore

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate, NSMenuDelegate {
    var onOpenSettings: ((SettingsPane?) -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "display", accessibilityDescription: "Great Display")
            button.image?.isTemplate = true
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Great Display — Option-click for Settings, right-click for quick actions"
        }

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = MenuView(onOpenSettings: { [weak self] pane in
            self?.popover.performClose(nil)
            self?.onOpenSettings?(pane)
        })
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting

        // A mode change on any display can move every display's origin and the
        // status item with it; NSPopover does not follow on its own, which left
        // the menu stranded mid-screen. Re-anchor whenever the layout changes.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.reanchorPopover() }
        }
        DisplayManager.shared.modeDidChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reanchorPopover() }
            .store(in: &cancellables)
        DisplayManager.shared.$displays
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reanchorPopover() }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(forName: .greatDisplayShowMenu, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.popover.isShown else { return }
                self.togglePopover()
            }
        }

        // Optional brightness percentage next to the icon.
        Publishers.CombineLatest(DisplayController.shared.$brightness, SettingsStore.shared.$state)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, state in self?.updateTitle(showPercentage: state.general.menuBarShowsPercentage) }
            .store(in: &cancellables)
    }

    private func updateTitle(showPercentage: Bool) {
        guard let button = statusItem.button else { return }
        guard showPercentage,
              let main = DisplayController.shared.displays.first(where: { $0.isMain }) ?? DisplayController.shared.displays.first else {
            button.title = ""
            return
        }
        let value = DisplayController.shared.combinedBrightness(for: main)
        button.title = " \(Int((value * 100).rounded()))%"
        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return togglePopover() }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            showQuickMenu()
        } else if event.modifierFlags.contains(.option) {
            popover.performClose(nil)
            onOpenSettings?(nil)
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        DisplayController.shared.menuWillOpen()
        SystemColorsController.shared.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        raisePopover()
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Moves a shown popover back under the status item. The status bar window
    /// is repositioned asynchronously after a reconfiguration, so this runs now
    /// and again shortly after.
    private func reanchorPopover() {
        guard popover.isShown else { return }
        for delay in [0.0, 0.25, 0.8] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.popover.isShown, let button = self.statusItem.button,
                      button.window != nil else { return }
                self.popover.positioningRect = button.bounds
                self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                self.raisePopover()
            }
        }
    }

    /// A status-item popover opens at the status-bar level (25), under a
    /// self-stream window that covers the menu bar. Lift it to the menu level
    /// so the app menu always opens on top of any stream.
    private func raisePopover() {
        popover.contentViewController?.view.window?.level = .popUpMenu
    }

    func popoverDidClose(_ notification: Notification) {
        MenuState.shared.menuDidClose()
    }

    // MARK: Quick menu (right-click)

    private func showQuickMenu() {
        popover.performClose(nil)
        let colors = SystemColorsController.shared
        colors.refresh()
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Connect All Displays", #selector(connectAll),
                          enabled: !DisplayController.shared.disconnected.isEmpty))
        menu.addItem(item("Redetect Displays", #selector(redetect)))
        menu.addItem(.separator())
        menu.addItem(item("Enable Dark Mode", #selector(toggleDark), state: colors.darkMode))
        menu.addItem(item("Enable Night Shift", #selector(toggleNightShift), state: colors.nightShift == true,
                          enabled: colors.nightShift != nil))
        menu.addItem(item("Enable True Tone", #selector(toggleTrueTone), state: colors.trueTone == true,
                          enabled: colors.trueTone != nil))
        menu.addItem(item("Prevent Sleep", #selector(togglePreventSleep), state: SleepController.shared.isPreventingSleep))
        menu.addItem(.separator())
        menu.addItem(item("Quit Great Display", #selector(quit), key: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Detach so the next left click opens the popover again.
        statusItem.menu = nil
    }

    private func item(_ title: String, _ action: Selector, key: String = "", state: Bool = false,
                      enabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: enabled ? action : nil, keyEquivalent: key)
        item.target = self
        item.state = state ? .on : .off
        return item
    }

    @objc private func openSettings() { onOpenSettings?(nil) }
    @objc private func connectAll() { DisplayController.shared.reconnectAll() }
    @objc private func redetect() { DisplayController.shared.redetect() }
    @objc private func toggleDark() { SystemColorsController.shared.setDarkMode(!SystemColorsController.shared.darkMode) }
    @objc private func toggleNightShift() {
        SystemColorsController.shared.setNightShift(!(SystemColorsController.shared.nightShift ?? false))
    }
    @objc private func toggleTrueTone() {
        SystemColorsController.shared.setTrueTone(!(SystemColorsController.shared.trueTone ?? false))
    }
    @objc private func togglePreventSleep() {
        SleepController.shared.setPreventSleep(!SleepController.shared.isPreventingSleep)
    }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}
