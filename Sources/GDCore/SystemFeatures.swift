import Foundation
import AppKit
import SwiftUI
import IOKit.pwr_mgt
import GDCBridge

/// Dark Mode, Night Shift and True Tone in one place (the "System Colors"
/// tool in the app menu).
@MainActor
public final class SystemColorsController: ObservableObject {
    public static let shared = SystemColorsController()

    @Published public private(set) var darkMode = false
    @Published public private(set) var nightShift: Bool?
    @Published public private(set) var trueTone: Bool?

    private init() {
        refresh()
        DistributedNotificationCenter.default().addObserver(forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
                                                            object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    public func refresh() {
        darkMode = gd_dark_mode() == 1
        let night = gd_night_shift()
        nightShift = night < 0 ? nil : night == 1
        let tone = gd_true_tone()
        trueTone = tone < 0 ? nil : tone == 1
    }

    public func setDarkMode(_ enabled: Bool) {
        if gd_set_dark_mode(enabled ? 1 : 0) != 0 {
            // Fallback through System Events (needs Automation permission).
            let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(enabled)"
            NSAppleScript(source: script)?.executeAndReturnError(nil)
        }
        darkMode = enabled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.refresh() }
    }

    public func setNightShift(_ enabled: Bool) {
        _ = gd_set_night_shift(enabled ? 1 : 0)
        refresh()
    }

    public func setTrueTone(_ enabled: Bool) {
        _ = gd_set_true_tone(enabled ? 1 : 0)
        refresh()
    }
}

/// Keeps the Mac and its displays awake through a power-management assertion.
@MainActor
public final class SleepController: ObservableObject {
    public static let shared = SleepController()

    @Published public private(set) var isPreventingSleep = false
    private var assertionID: IOPMAssertionID = 0

    private init() {}

    public func setPreventSleep(_ enabled: Bool) {
        if enabled == isPreventingSleep { return }
        if enabled {
            let reason = "Great Display: Prevent Sleep" as CFString
            let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                                                     IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                     reason,
                                                     &assertionID)
            isPreventingSleep = result == kIOReturnSuccess
        } else {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            isPreventingSleep = false
        }
        SettingsStore.shared.state.general.preventSleep = isPreventingSleep
    }
}

/// Highlights a physical screen with a frame and a large label.
@MainActor
public final class IdentifyController {
    public static let shared = IdentifyController()
    private var windows: [NSWindow] = []
    private var hideWork: DispatchWorkItem?

    private init() {}

    public func identify(_ display: DisplayInfo) {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.id
        }) else {
            OSDController.shared.show(symbol: "display", title: display.name, value: 1, detail: display.resolutionSummary)
            return
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()

        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.contentView = NSHostingView(rootView: IdentifyOverlay(display: display))
        window.setFrame(screen.frame, display: true)
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { $0.duration = 0.15; window.animator().alphaValue = 1 }
        windows.append(window)

        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let current = self.windows
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                current.forEach { $0.animator().alphaValue = 0 }
            }, completionHandler: {
                Task { @MainActor in
                    current.forEach { $0.orderOut(nil) }
                    self.windows.removeAll { current.contains($0) }
                }
            })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}

private struct IdentifyOverlay: View {
    let display: DisplayInfo

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 10)
            VStack(spacing: 8) {
                Image(systemName: display.isBuiltIn ? "laptopcomputer" : (display.isVirtual ? "rectangle.dashed" : "display"))
                    .font(.system(size: 54, weight: .light))
                Text(display.name)
                    .font(.system(size: 34, weight: .semibold))
                Text("\(display.resolutionSummary)\(display.isMain ? " · Main Display" : "")")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 30)
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .padding(2)
    }
}
