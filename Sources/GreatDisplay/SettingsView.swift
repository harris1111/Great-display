import SwiftUI
import AppKit
import GDCore
import ServiceManagement

enum SettingsPane: Hashable {
    case displays
    case display(CGDirectDisplayID)
    case virtualScreens
    case virtualScreen(UUID)
    case application
    case menu
    case keyboard
    case about

    /// The sidebar item a pane belongs to.
    var section: SettingsSection {
        switch self {
        case .displays, .display, .virtualScreens, .virtualScreen: return .displays
        case .application: return .application
        case .menu: return .menu
        case .keyboard: return .keyboard
        case .about: return .about
        }
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case displays = "Displays"
    case application = "Application"
    case menu = "Menu"
    case keyboard = "Keyboard"
    case about = "About"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .displays: return "display.2"
        case .application: return "switch.2"
        case .menu: return "menubar.rectangle"
        case .keyboard: return "keyboard"
        case .about: return "info.circle"
        }
    }

    var pane: SettingsPane {
        switch self {
        case .displays: return .displays
        case .application: return .application
        case .menu: return .menu
        case .keyboard: return .keyboard
        case .about: return .about
        }
    }
}

@MainActor
final class SettingsNavigation: ObservableObject {
    static let shared = SettingsNavigation()
    @Published var selection: SettingsPane? = .displays
    /// Remembers the last device tab so returning to Displays restores it.
    private var lastDisplayPane: SettingsPane = .displays

    func select(_ section: SettingsSection) {
        if section == .displays {
            selection = lastDisplayPane
        } else {
            if let current = selection, current.section == .displays { lastDisplayPane = current }
            selection = section.pane
        }
    }

    func selectDevice(_ pane: SettingsPane) {
        lastDisplayPane = pane
        selection = pane
    }
}

extension Notification.Name {
    /// Asks the menu bar controller to open the app menu.
    static let greatDisplayShowMenu = Notification.Name("GreatDisplayShowMenu")
}

// MARK: - Window layout

struct SettingsView: View {
    @ObservedObject private var navigation = SettingsNavigation.shared

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar()
                .frame(width: 210)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(SettingsStyle.contentBackground)
        }
        .ignoresSafeArea()
        .frame(minWidth: 880, minHeight: 620)
    }

    @ViewBuilder
    private var detail: some View {
        switch (navigation.selection ?? .displays).section {
        case .displays: DisplaysPage()
        case .application: ApplicationSettingsView()
        case .menu: MenuSettingsView()
        case .keyboard: KeyboardSettingsView()
        case .about: AboutView()
        }
    }
}

struct SettingsSidebar: View {
    @ObservedObject private var navigation = SettingsNavigation.shared
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color.clear.frame(height: 48)   // traffic lights
            ForEach(SettingsSection.allCases) { section in
                SidebarItem(section: section,
                            selected: (navigation.selection ?? .displays).section == section) {
                    navigation.select(section)
                }
            }
            Spacer()
            HStack {
                Text("Show help").font(.system(size: 12))
                Spacer()
                Toggle("", isOn: $store.state.general.showHelp)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
            Divider().padding(.horizontal, 12)
            VStack(alignment: .leading, spacing: 8) {
                SidebarLink(symbol: "arrow.right.circle", title: "App Menu") {
                    NotificationCenter.default.post(name: .greatDisplayShowMenu, object: nil)
                }
                SidebarLink(symbol: "stethoscope", title: "Diagnostics") {
                    navigation.select(.application)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background(VisualEffectBackground(material: .sidebar))
    }
}

private struct SidebarItem: View {
    let section: SettingsSection
    let selected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbol)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26)
                Text(section.rawValue)
                    .font(.system(size: 13.5))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.primary.opacity(0.11) : (hovering ? Color.primary.opacity(0.05) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct SidebarLink: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Displays page with the device bar

struct DisplaysPage: View {
    @ObservedObject private var navigation = SettingsNavigation.shared
    @ObservedObject private var controller = DisplayController.shared

    private var selection: SettingsPane { navigation.selection ?? .displays }

    var body: some View {
        VStack(spacing: 0) {
            DeviceBar(selection: selection) { navigation.selectDevice($0) }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: 900, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .virtualScreen(let id):
            VirtualScreenPage(configurationID: id)
        case .display(let id):
            if let screen = VirtualScreenManager.shared.active.first(where: { $0.displayID == id }) {
                VirtualScreenPage(configurationID: screen.id)
            } else if let display = controller.display(id) {
                DisplaySettingsView(display: display)
            } else if let entry = controller.disconnected.first(where: { $0.id == id }) {
                DisconnectedDisplayView(entry: entry)
            } else {
                DisplaysOverviewView()
            }
        case .virtualScreens:
            VirtualScreensOverview()
        default:
            DisplaysOverviewView()
        }
    }
}

/// Grey bar across the top of the Displays page: Overview, one large icon per
/// display, and Virtual Screens, with a notch under the selected one.
struct DeviceBar: View {
    let selection: SettingsPane
    let select: (SettingsPane) -> Void
    @ObservedObject private var controller = DisplayController.shared
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var virtualScreens = VirtualScreenManager.shared
    @State private var creating = false

    private func isSelected(_ configuration: VirtualScreenConfiguration) -> Bool {
        if selection == .virtualScreen(configuration.id) { return true }
        if case .display(let id) = selection, virtualScreens.displayID(for: configuration) == id { return true }
        return false
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 6) {
                DeviceTab(title: "Overview", selected: selection == .displays, action: { select(.displays) }) {
                    ZStack {
                        Circle().fill(Color.primary.opacity(0.12)).frame(width: 54, height: 54)
                        Image(systemName: "list.bullet")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1, height: 96).padding(.horizontal, 8)
                // Physical displays (and virtual displays made by other apps).
                ForEach(controller.displays.filter { display in
                    !virtualScreens.active.contains { $0.displayID == display.id }
                }) { display in
                    let selected = selection == .display(display.id)
                    DeviceTab(title: display.name, selected: selected, action: { select(.display(display.id)) }) {
                        DeviceGlyph(symbol: DisplayGlyph.symbol(for: display), selected: selected, dimmed: false)
                    }
                }
                ForEach(controller.disconnected) { entry in
                    let selected = selection == .display(entry.id)
                    DeviceTab(title: entry.name, selected: selected, action: { select(.display(entry.id)) }) {
                        DeviceGlyph(symbol: "display", selected: selected, dimmed: true)
                    }
                }
                // Virtual screens, connected or not.
                ForEach(store.state.virtualScreens) { configuration in
                    let selected = isSelected(configuration)
                    DeviceTab(title: configuration.name, selected: selected,
                              action: { select(.virtualScreen(configuration.id)) }) {
                        DeviceGlyph(symbol: "rectangle.dashed", selected: selected,
                                    dimmed: !virtualScreens.isActive(configuration))
                    }
                }
                DeviceTab(title: "New Virtual Screen", selected: false, action: { creating = true }) {
                    DeviceGlyph(symbol: "plus.rectangle.on.rectangle", selected: false, dimmed: false)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 168, alignment: .bottom)
        .sheet(isPresented: $creating) { NewVirtualScreenSheet() }
        .background(
            VisualEffectBackground(material: .headerView, blending: .withinWindow)
                .overlay(Color.primary.opacity(0.03))
        )
        .overlay(alignment: .bottom) { Divider() }
    }
}

enum DisplayGlyph {
    static func symbol(for display: DisplayInfo) -> String {
        if display.isBuiltIn { return "laptopcomputer" }
        if display.isVirtual { return "rectangle.dashed" }
        if display.name.localizedCaseInsensitiveContains("displaylink") { return "rectangle.on.rectangle.angled" }
        return "display"
    }
}

private struct DeviceGlyph: View {
    let symbol: String
    let selected: Bool
    let dimmed: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 50, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(selected ? Color.accentColor : Color.secondary)
            .opacity(dimmed ? 0.45 : 1)
            .frame(width: 64, height: 56)
    }
}

private struct DeviceTab<Icon: View>: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon()
                    .scaleEffect(hovering && !selected ? 1.04 : 1)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 120, height: 32, alignment: .top)
                // Notch pointing into the page below the selected device.
                NotchTriangle()
                    .fill(selected ? SettingsStyle.contentBackground : Color.clear)
                    .frame(width: 22, height: 10)
            }
            .frame(width: 132)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

// MARK: - Overview

struct DisplaysOverviewView: View {
    @ObservedObject private var controller = DisplayController.shared
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var navigation = SettingsNavigation.shared

    var body: some View {
        SettingsCard {
            ForEach(Array(controller.displays.enumerated()), id: \.element.id) { index, display in
                if index > 0 { SettingsRowDivider() }
                Button { navigation.selectDevice(.display(display.id)) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: DisplayGlyph.symbol(for: display))
                            .font(.system(size: 22))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(display.name).font(.system(size: 13, weight: .medium))
                            Text(overviewDetail(display)).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, SettingsStyle.rowInset)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            ForEach(controller.disconnected) { entry in
                SettingsRowDivider()
                SettingsRow(title: entry.name, help: "Disconnected. The display keeps its power but is not part of the desktop.") {
                    Button("Connect") { controller.reconnect(entry.id) }
                }
            }
        }

        SettingsSectionTitle(title: "Connections")
        SettingsCard {
            SettingsHelpText(text: "Reconnect displays that were disconnected from the app menu, or re-read the display list after plugging displays in or out.")
            SettingsButtonRow {
                Button("Redetect Displays") { controller.redetect() }
                Button("Connect All Displays") { controller.reconnectAll() }
                    .disabled(controller.disconnected.isEmpty)
            }
        }

        SettingsSectionTitle(title: "Saved Settings")
        SettingsCard {
            SettingsToggleRow(title: "Restore display configuration on launch",
                              help: "Re-applies each display's saved resolution, arrangement and main-display choice when Great Display starts.",
                              isOn: $store.state.general.restoreConfigurationOnLaunch)
            SettingsRowDivider()
            SettingsHelpText(text: "Settings are stored per display identity (vendor, model and serial number), so they follow a display between ports.")
            SettingsButtonRow {
                Button("Reset All Saved Settings…", role: .destructive) { confirmReset() }
            }
        }
    }

    private func overviewDetail(_ display: DisplayInfo) -> String {
        var parts = [display.resolutionSummary]
        if display.isMain { parts.append("Main display") }
        if controller.ddcAvailable(display) { parts.append("DDC") }
        if display.isMirrored { parts.append("Mirrored") }
        return parts.joined(separator: " · ")
    }

    private func confirmReset() {
        let alert = NSAlert()
        alert.messageText = "Reset all saved settings?"
        alert.informativeText = "Everything returns to its defaults: application, menu and keyboard preferences, saved display configurations, image adjustments, per-display preferences, stream options and virtual screen definitions. Connected virtual screens are disconnected and running streams stop."
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            for display in controller.displays { controller.resetImageAdjustments(for: display) }
            // Their definitions are about to go: a screen or stream left
            // running would have no page to stop it from.
            FullScreenStreamController.shared.stopAll()
            VirtualScreenManager.shared.destroyAll()
            store.resetAll()
            // Brightness key handling is on by default again; the tap only
            // starts here when Accessibility access is already granted.
            if store.state.general.handleBrightnessKeys { _ = KeyboardController.shared.start() }
        }
    }
}

struct DisconnectedDisplayView: View {
    let entry: DisconnectedDisplay
    @ObservedObject private var controller = DisplayController.shared

    var body: some View {
        SettingsCard {
            SettingsRow(title: "Display name", value: entry.name)
            SettingsRowDivider()
            SettingsRow(title: "Display status", value: "Disconnected")
        }
        SettingsCard {
            SettingsToggleRow(title: "Connect this display",
                              help: "The display was removed from the desktop by Great Display. Switch on to bring it back.",
                              isOn: Binding(get: { false }, set: { if $0 { controller.reconnect(entry.id) } }))
        }
    }
}

// MARK: - Individual display

struct DisplaySettingsView: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var virtualScreens = VirtualScreenManager.shared
    @State private var showInformation = false
    @State private var showDDCAdvanced = false

    private var preferences: Binding<DisplayPreferences> {
        Binding(get: { store.preferences(for: display.identity) },
                set: { store.setPreferences($0, for: display.identity) })
    }

    var body: some View {
        // Identity and connection
        SettingsCard {
            SettingsRow(title: "Display name", value: display.name)
            SettingsRowDivider()
            SettingsRow(title: "Display type", value: displayType)
            SettingsRowDivider()
            SettingsRow(title: "Display status", value: displayStatus)
        }

        SettingsCard {
            SettingsToggleRow(title: "Connect this display",
                              help: display.isVirtual
                                ? "Switching off disconnects the virtual screen; its definition is kept."
                                : "Switching off removes the display from the desktop without cutting its power.",
                              isOn: Binding(get: { true }, set: { if !$0 { disconnect() } }),
                              enabled: display.isVirtual ? !connectionFollowsAssociation : canDisconnect)
            SettingsRowDivider()
            SettingsButtonRow {
                Button("Identify Visually") { controller.identify(display) }
                Button("Display Information…") { showInformation = true }
            }
        }

        SettingsSectionTitle(title: "General Settings")
        SettingsCard {
            SettingsToggleRow(title: "Show in the app menu",
                              help: "Determines whether the display is presented in the app menu.",
                              isOn: preferences.showInMenu)
            SettingsRowDivider()
            SettingsToggleRow(title: "Keyboard control affects this display",
                              help: "Determines whether the brightness keys (and, for monitor speakers, the volume keys) adjust this display.",
                              isOn: preferences.keyboardControl)
            SettingsRowDivider()
            SettingsToggleRow(title: "Main display",
                              help: "The main display holds the menu bar and the Dock.",
                              isOn: Binding(get: { display.isMain }, set: { if $0 { controller.setMain(display) } }),
                              enabled: !display.isMain)
        }

        ResolutionSettingsCard(display: display)
        BrightnessSettingsCard(display: display)

        SettingsSectionTitle(title: "Image Adjustments")
        SettingsCard {
            SettingsHelpText(text: "Applied through the display's color table, so they work on every display. Values are saved per display and can clip HDR content.")
            ImageAdjustmentsForm(display: display)
        }

        SettingsSectionTitle(title: "Device Control")
        DeviceControlCard(display: display, showAdvanced: $showDDCAdvanced)

        Color.clear.frame(height: 4)
            .sheet(isPresented: $showInformation) { DisplayInformationSheet(display: display) }
            .sheet(isPresented: $showDDCAdvanced) { DDCAdvancedSheet(display: display) }
    }

    private var canDisconnect: Bool {
        DisplayManager.shared.canDisconnect && controller.displays.filter { !$0.isVirtual }.count > 1
    }

    /// A virtual screen whose association rule decides when it is connected:
    /// switching it off by hand would be undone by the rule.
    private var connectionFollowsAssociation: Bool {
        guard let active = virtualScreens.active.first(where: { $0.displayID == display.id }) else { return false }
        let saved = store.state.virtualScreens.first { $0.id == active.id } ?? active.configuration
        return saved.connectionFollowsAssociation
    }

    private var displayType: String {
        if display.isBuiltIn { return "Built-in display" }
        if display.isVirtual { return "Virtual screen" }
        if display.name.localizedCaseInsensitiveContains("displaylink") { return "DisplayLink display" }
        if display.vendorID == 0x0610 { return "Apple external display" }
        return "Third-party external display"
    }

    private var displayStatus: String {
        var parts = ["Connected"]
        if display.isMain { parts.append("Main display") }
        if display.isMirrored { parts.append("Mirrored") }
        if controller.hdrEnabled.contains(display.id) { parts.append("HDR") }
        return parts.joined(separator: " · ")
    }

    private func disconnect() {
        if display.isVirtual {
            if let active = virtualScreens.active.first(where: { $0.displayID == display.id }) {
                virtualScreens.destroy(active.id)
            }
        } else {
            if display.isMain {
                let alert = NSAlert()
                alert.messageText = "Disconnect \(display.name)?"
                alert.informativeText = "This is the main display. The menu bar and Dock move to another display. It can be reconnected from the app menu or from Settings."
                alert.addButton(withTitle: "Disconnect")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
            // Stay on this page when the display could not be disconnected.
            guard controller.disconnect(display) else { return }
        }
        SettingsNavigation.shared.selectDevice(.displays)
    }
}

private struct ResolutionSettingsCard: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared

    var body: some View {
        SettingsSectionTitle(title: "Resolution and Orientation")
        SettingsCard {
            SettingsRow(title: "Display mode", help: "Desktop size and density. HiDPI modes render at twice the size for sharp text.") {
                Picker("", selection: modeBinding) {
                    ForEach(modes) { mode in
                        Text("\(mode.resolutionText)\(mode.isHiDPI ? " HiDPI" : "") · \(mode.refreshText)").tag(mode.id)
                    }
                    if !modes.contains(where: { $0.id == currentID }) {
                        Text(display.resolutionSummary).tag(currentID)
                    }
                }
                .labelsHidden()
                .frame(width: 260)
            }
            let rates = controller.refreshRates(for: display)
            if rates.count > 1 {
                SettingsRowDivider()
                SettingsRow(title: "Refresh rate") {
                    Picker("", selection: modeBinding) {
                        ForEach(rates) { Text($0.refreshText).tag($0.id) }
                        if !rates.contains(where: { $0.id == currentID }) {
                            Text(controller.effectiveMode(for: display)?.refreshText ?? "—").tag(currentID)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
            SettingsRowDivider()
            SettingsToggleRow(title: "High resolution (HiDPI)",
                              help: "Switches between the pixel-doubled and low-density variant of the current size.",
                              isOn: Binding(get: { controller.effectiveMode(for: display)?.isHiDPI == true },
                                            set: { _ in controller.toggleHiDPI(for: display) }),
                              enabled: hasDensityCounterpart)
            if controller.canRotate.contains(display.id) {
                SettingsRowDivider()
                SettingsRow(title: "Rotation") {
                    Picker("", selection: Binding(get: { controller.rotation(for: display) },
                                                  set: { controller.setRotation($0, for: display) })) {
                        Text("Standard").tag(0)
                        Text("90°").tag(90)
                        Text("180°").tag(180)
                        Text("270°").tag(270)
                    }
                    .labelsHidden()
                    .frame(width: 140)
                }
            }
            if controller.hdrCapable.contains(display.id) {
                SettingsRowDivider()
                SettingsToggleRow(title: "High Dynamic Range",
                                  isOn: Binding(get: { controller.hdrEnabled.contains(display.id) },
                                                set: { controller.setHDR($0, for: display) }))
            }
            if !display.isMain {
                SettingsRowDivider()
                SettingsRow(title: "Move display", help: "Places the display edge to edge with the main display.") {
                    HStack(spacing: 4) {
                        ForEach(DisplayManager.Placement.allCases) { placement in
                            Button { controller.place(display, placement) } label: {
                                Image(systemName: placement.symbol).frame(width: 18)
                            }
                            .help(placement.rawValue)
                        }
                    }
                }
            }
        }
    }

    private var currentID: Int { controller.effectiveMode(for: display)?.id ?? -1 }

    private var modes: [ModeInfo] {
        display.modes.filter(\.isUsable)
            .sorted { $0.width == $1.width ? ($0.isHiDPI == $1.isHiDPI ? $0.refreshRate > $1.refreshRate : $0.isHiDPI) : $0.width > $1.width }
    }

    private var modeBinding: Binding<Int> {
        Binding(get: { currentID },
                set: { id in if let mode = display.modes.first(where: { $0.id == id }) { controller.setMode(mode, for: display) } })
    }

    private var hasDensityCounterpart: Bool {
        guard let mode = controller.effectiveMode(for: display) else { return false }
        return display.modes.contains { $0.width == mode.width && $0.height == mode.height && $0.isHiDPI != mode.isHiDPI }
    }
}

private struct BrightnessSettingsCard: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared

    var body: some View {
        SettingsSectionTitle(title: "Brightness")
        SettingsCard {
            SettingsRow(title: "Brightness control", value: brightnessKind,
                        help: controller.usesCombinedBrightness(display)
                            ? "One control: the monitor's own backlight first, then color-table dimming below its minimum."
                            : nil)
            SettingsRowDivider()
            let value = controller.combinedBrightness(for: display)
            SettingsSliderRow(title: "Brightness",
                              value: Binding(get: { controller.combinedBrightness(for: display) },
                                             set: { controller.setCombinedBrightness($0, for: display, showOSD: false) }),
                              text: "\(Int((value * 100).rounded()))%")
            SettingsRowDivider()
            // With combined brightness the slider above already drives the
            // color-table dimming (its lower quarter). A second control for the
            // same value made that slider jump and then drop the backlight.
            if !controller.usesCombinedBrightness(display) {
                let dimming = controller.dimming(for: display.id)
                SettingsSliderRow(title: "Software dimming",
                                  help: "Extra dimming through the color table, independent of the backlight.",
                                  value: Binding(get: { controller.dimming(for: display.id) },
                                                 set: { controller.setDimming($0, for: display) }),
                                  range: 0.1...1,
                                  text: "\(Int((dimming * 100).rounded()))%")
                SettingsRowDivider()
            }
            SettingsButtonRow {
                Button("Reset Brightness and Dimming") { controller.resetAdjustments(for: display) }
            }
        }
    }

    private var brightnessKind: String {
        if controller.usesCombinedBrightness(display) {
            return controller.ddcAvailable(display) && !display.hasHardwareBrightness ? "Combined (DDC + software)" : "Combined (native + software)"
        }
        if display.hasHardwareBrightness { return "Native" }
        if controller.ddcAvailable(display) { return "DDC/CI" }
        return "Software dimming"
    }
}

struct ImageAdjustmentsForm: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared

    private func binding(_ keyPath: WritableKeyPath<ImageAdjustments, Double>) -> Binding<Double> {
        Binding(get: { controller.adjustments(for: display.id)[keyPath: keyPath] },
                set: { value in
                    var copy = controller.adjustments(for: display.id)
                    copy[keyPath: keyPath] = value
                    controller.setAdjustments(copy, for: display)
                })
    }

    private func boolBinding(_ keyPath: WritableKeyPath<ImageAdjustments, Bool>) -> Binding<Bool> {
        Binding(get: { controller.adjustments(for: display.id)[keyPath: keyPath] },
                set: { value in
                    var copy = controller.adjustments(for: display.id)
                    copy[keyPath: keyPath] = value
                    controller.setAdjustments(copy, for: display)
                })
    }

    var body: some View {
        let value = controller.adjustments(for: display.id)
        SettingsSliderRow(title: "Gamma", value: binding(\.gamma), range: 0.4...2.2, text: String(format: "%.2f", value.gamma))
        SettingsRowDivider()
        SettingsSliderRow(title: "Color temperature", value: binding(\.temperature), range: -1...1,
                          text: value.temperature == 0 ? "Neutral" : String(format: "%+.0f", value.temperature * 100))
        SettingsRowDivider()
        SettingsSliderRow(title: "Contrast", value: binding(\.contrast), range: 0.5...1.5,
                          text: String(format: "%.0f%%", (value.contrast - 0.5) * 100))
        SettingsRowDivider()
        SettingsSliderRow(title: "Gain (red)", value: binding(\.redGain), text: String(format: "%.0f%%", value.redGain * 100))
        SettingsRowDivider()
        SettingsSliderRow(title: "Gain (green)", value: binding(\.greenGain), text: String(format: "%.0f%%", value.greenGain * 100))
        SettingsRowDivider()
        SettingsSliderRow(title: "Gain (blue)", value: binding(\.blueGain), text: String(format: "%.0f%%", value.blueGain * 100))
        SettingsRowDivider()
        SettingsToggleRow(title: "Invert colors", isOn: boolBinding(\.invert))
        SettingsRowDivider()
        SettingsToggleRow(title: "Suspend image adjustments",
                          help: "Temporarily bypasses the adjustments above without losing them.",
                          isOn: boolBinding(\.suspended))
        SettingsRowDivider()
        SettingsButtonRow {
            Button("Reset Image Adjustments") { controller.resetImageAdjustments(for: display) }
                .disabled(value == .neutral)
        }
    }
}

// MARK: - Device control (DDC)

private struct DeviceControlCard: View {
    let display: DisplayInfo
    @Binding var showAdvanced: Bool
    @ObservedObject private var controller = DisplayController.shared

    var body: some View {
        if controller.ddcAvailable(display) {
            available
        } else if display.hasDDC && controller.ddcInfo[display.id]?.responsive == false {
            SettingsCard {
                SettingsIconHeader(symbol: "exclamationmark.triangle.fill", title: "DDC Control", tint: .orange,
                                   subtitle: "Not responding")
                SettingsHelpText(text: "The monitor does not answer DDC/CI requests, so brightness uses software dimming. Enable DDC/CI in the monitor's on-screen menu, or connect it directly instead of through a dock or adapter.")
                SettingsRowDivider()
                SettingsButtonRow {
                    Button("Try Again") {
                        let id = display.id
                        // Waits for a DDC transaction in progress, and a slow
                        // probe of this very monitor is the likely one: keep
                        // that wait off the main thread.
                        DispatchQueue.global(qos: .userInitiated).async {
                            DDCController.shared.invalidate(display: id)
                            DispatchQueue.main.async { controller.redetect() }
                        }
                    }
                }
            }
        } else if display.hasDDC {
            SettingsCard {
                SettingsIconHeader(symbol: "slider.horizontal.3", title: "DDC Control", subtitle: "Checking the monitor…")
            }
        } else {
            SettingsCard {
                SettingsIconHeader(symbol: "slider.horizontal.3", title: "DDC Control", tint: .gray,
                                   subtitle: display.isVirtual ? "Not available for virtual screens" : "No hardware control path")
                SettingsHelpText(text: "DDC allows hardware backlight, volume, input selection and other monitor features. This display has no DDC/CI channel; brightness and image adjustments use the color table.")
            }
        }
    }

    @ViewBuilder
    private var available: some View {
        let info = controller.ddcInfo[display.id]
        let caps = info?.capabilities
        SettingsCard {
            SettingsIconHeader(symbol: "slider.horizontal.3", title: "DDC Control",
                               subtitle: caps.map { "\($0.model ?? "Monitor") · MCCS \($0.mccsVersion ?? "?") · \($0.codes.count) controls" }
                                   ?? "Responding · reading capabilities…")
            SettingsHelpText(text: "DDC allows for hardware backlight, volume control, input selection and various other features. Requires a compatible external display.")
            SettingsRowDivider()
            if let contrast = controller.contrast(for: display.id) {
                SettingsSliderRow(title: "Contrast (hardware)",
                                  value: Binding(get: { controller.contrast(for: display.id) ?? contrast },
                                                 set: { controller.setContrast($0, for: display) }),
                                  text: "\(Int((contrast * 100).rounded()))%")
                SettingsRowDivider()
            }
            if let volume = controller.volume(for: display.id) {
                SettingsSliderRow(title: "Volume",
                                  help: "The volume keys control this when macOS plays audio through the monitor.",
                                  value: Binding(get: { controller.volume(for: display.id) ?? volume },
                                                 set: { controller.setVolume($0, for: display) }),
                                  text: controller.mute[display.id] == true ? "Muted" : "\(Int((volume * 100).rounded()))%")
                SettingsRowDivider()
                SettingsToggleRow(title: "Mute",
                                  isOn: Binding(get: { controller.mute[display.id] == true },
                                                set: { _ in controller.toggleMute(for: display) }))
                SettingsRowDivider()
            }
            SettingsRow(title: "Input source", help: "Switching away from the Mac's input shows another source on the monitor.") {
                Picker("", selection: Binding(
                    get: { controller.inputSource[display.id] ?? -1 },
                    set: { value in
                        if let source = controller.inputSources(for: display).first(where: { $0.value == value }) {
                            controller.setInputSource(source, for: display)
                        }
                    })) {
                    if controller.inputSource[display.id] == nil { Text("Unknown").tag(-1) }
                    ForEach(controller.inputSources(for: display)) { Text($0.name).tag($0.value) }
                }
                .labelsHidden()
                .frame(width: 180)
            }
            if let modes = caps?.codes[DisplayController.pictureModeCode], !modes.isEmpty {
                SettingsRowDivider()
                ddcPicker("Picture mode", code: DisplayController.pictureModeCode, values: modes, name: DDCValueNames.pictureMode)
            }
            if let presets = caps?.codes[DDCController.VCP.colorPreset.rawValue], !presets.isEmpty {
                SettingsRowDivider()
                ddcPicker("Color preset", code: DDCController.VCP.colorPreset.rawValue, values: presets, name: DDCValueNames.colorPreset)
            }
            ForEach([DDCController.VCP.redGain, .greenGain, .blueGain, .sharpness], id: \.self) { vcp in
                if let value = controller.ddcValue(vcp.rawValue, for: display.id) {
                    SettingsRowDivider()
                    SettingsSliderRow(title: vcp == .sharpness ? "Sharpness" : "\(vcp.name) (hardware)",
                                      value: Binding(get: { controller.ddcValue(vcp.rawValue, for: display.id)?.fraction ?? 0 },
                                                     set: { controller.setDDC(code: vcp.rawValue,
                                                                              raw: Int(($0 * Double(max(1, value.maximum))).rounded()),
                                                                              for: display) }),
                                      text: "\(value.current)")
                }
            }
            SettingsRowDivider()
            SettingsButtonRow {
                Button("Restore Color Defaults…") {
                    confirm("Restore \(display.name)'s color defaults?", "The monitor resets its color settings.") {
                        controller.sendDDCCommand(code: DDCController.VCP.restoreColor.rawValue, value: 1, for: display)
                    }
                }
                .disabled(caps.map { !$0.supports(.restoreColor) } ?? false)
                Button("Advanced…") { showAdvanced = true }
            }
        }
    }

    private func ddcPicker(_ title: String, code: UInt8, values: [Int], name: @escaping (Int) -> String) -> some View {
        SettingsRow(title: title) {
            Picker("", selection: Binding(
                get: { controller.ddcValue(code, for: display.id)?.current ?? -1 },
                set: { controller.setDDC(code: code, raw: $0, for: display) })) {
                if controller.ddcValue(code, for: display.id) == nil { Text("Unknown").tag(-1) }
                ForEach(values, id: \.self) { Text(name($0)).tag($0) }
            }
            .labelsHidden()
            .frame(width: 180)
        }
    }

    private func confirm(_ title: String, _ message: String, action: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { action() }
    }
}

// MARK: - Sheets

private struct SheetScaffold<Content: View>: View {
    let title: String
    @Environment(\.dismiss) private var dismiss
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 16, weight: .bold))
            ScrollView { VStack(alignment: .leading, spacing: 10) { content() } }
            HStack {
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 600, height: 520)
    }
}

private struct DisplayInformationSheet: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared

    var body: some View {
        SheetScaffold(title: "\(display.name) — Display Information") {
            SettingsCard {
                SettingsRow(title: "Display ID", value: "\(display.id)")
                SettingsRowDivider()
                SettingsRow(title: "Vendor / model", value: String(format: "%04X / %04X", display.vendorID, display.modelID))
                SettingsRowDivider()
                SettingsRow(title: "Serial number", value: "\(display.serialNumber)")
                SettingsRowDivider()
                SettingsRow(title: "Current mode", value: display.currentMode.map {
                    "\($0.fullSummary) · \($0.refreshText) · \($0.aspectRatio)"
                } ?? "—")
                SettingsRowDivider()
                SettingsRow(title: "Scale", value: display.scaleSummary)
                SettingsRowDivider()
                SettingsRow(title: "Bounds", value: "\(Int(display.bounds.origin.x)), \(Int(display.bounds.origin.y)) · \(Int(display.bounds.width)) × \(Int(display.bounds.height))")
                SettingsRowDivider()
                SettingsRow(title: "Rotation", value: "\(controller.rotation(for: display))°")
                SettingsRowDivider()
                SettingsRow(title: "Modes", value: "\(display.modes.count) (\(display.modes.filter(\.isHiDPI).count) HiDPI)")
                SettingsRowDivider()
                SettingsRow(title: "Brightness path", value: display.hasHardwareBrightness ? "Native"
                            : (controller.ddcAvailable(display) ? "DDC/CI" : "Software"))
            }
        }
    }
}

private struct DDCAdvancedSheet: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared
    @State private var report: String?
    @State private var rawCode = "10"
    @State private var rawValue = ""
    @State private var rawResult: String?

    var body: some View {
        SheetScaffold(title: "\(display.name) — DDC Advanced") {
            if let caps = controller.ddcInfo[display.id]?.capabilities {
                SettingsCard {
                    SettingsRow(title: "Monitor", value: "\(caps.model ?? "—") · \(caps.type ?? "—") · MCCS \(caps.mccsVersion ?? "—")")
                    SettingsRowDivider()
                    SettingsRow(title: "Supported VCP codes") {
                        Text(caps.codes.keys.sorted().map { String(format: "%02X", $0) }.joined(separator: " "))
                            .font(.system(size: 11, design: .monospaced))
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                            .frame(maxWidth: 320, alignment: .trailing)
                    }
                }
            }
            SettingsCard {
                SettingsRow(title: "Raw VCP", help: "Reads or writes any VCP code. The code is hexadecimal (10, 0x60), the value decimal (0–65535). Writing unknown codes can change monitor settings.") {
                    HStack {
                        TextField("Code", text: $rawCode).frame(width: 54)
                        TextField("Value", text: $rawValue).frame(width: 64)
                        Button("Read") { rawRead() }
                        Button("Write") { rawWrite() }
                            .disabled(parsedRawValue == nil || parsedRawCode == nil)
                    }
                }
                if let rawResult {
                    SettingsRowDivider()
                    SettingsRow(title: "Result", value: rawResult)
                }
            }
            SettingsCard {
                SettingsButtonRow {
                    Button("Put Display in Standby…") { standby() }
                    Button("Read All Values") { readAll() }
                }
                if let report {
                    Text(report)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.horizontal, SettingsStyle.rowInset)
                        .padding(.bottom, 8)
                }
            }
        }
    }

    private func standby() {
        let alert = NSAlert()
        alert.messageText = "Put \(display.name) in standby?"
        alert.informativeText = "The monitor turns off its panel. It wakes on signal or from its power button."
        alert.addButton(withTitle: "Standby")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            controller.sendDDCCommand(code: DDCController.VCP.powerMode.rawValue, value: 0x04, for: display)
        }
    }

    /// The code field as a VCP code: hex, with or without a `0x` prefix.
    private var parsedRawCode: UInt8? {
        let text = rawCode.trimmingCharacters(in: .whitespaces).lowercased()
        return UInt8(text.hasPrefix("0x") ? String(text.dropFirst(2)) : text, radix: 16)
    }

    /// The value field, when it is a value a VCP write can carry.
    private var parsedRawValue: Int? {
        guard let value = Int(rawValue.trimmingCharacters(in: .whitespaces)), (0...0xFFFF).contains(value) else {
            return nil
        }
        return value
    }

    /// Codes that reset the monitor, switch its input or power it down. Their
    /// dedicated controls ask first, so the raw path does too.
    private static let disruptiveCodes: [UInt8: String] = [
        0x04: "restores the monitor's factory defaults",
        0x05: "restores the factory brightness and contrast",
        0x06: "restores the factory geometry",
        0x08: "restores the factory color settings",
        0x0A: "restores the factory TV defaults",
        0x60: "switches the monitor's input, which can leave this Mac without a picture on it",
        0xD6: "changes the monitor's power mode and can turn the panel off",
    ]

    private func rawRead() {
        guard let code = parsedRawCode else { rawResult = "invalid code"; return }
        let id = display.id
        rawResult = "…"
        DispatchQueue.global(qos: .userInitiated).async {
            let reading = DDCController.shared.reading(code: code, display: id)
            DispatchQueue.main.async {
                switch reading {
                case let .value(current, maximum): rawResult = "\(current) / \(maximum)"; rawValue = "\(current)"
                case .unsupported: rawResult = "unsupported"
                case .noReply: rawResult = "no reply"
                }
            }
        }
    }

    private func rawWrite() {
        guard let code = parsedRawCode, let value = parsedRawValue else {
            rawResult = "invalid code or value"
            return
        }
        if let effect = Self.disruptiveCodes[code] {
            let alert = NSAlert()
            alert.messageText = String(format: "Write %d to VCP code %02X on %@?", value, code, display.name)
            alert.informativeText = "This code \(effect)."
            alert.addButton(withTitle: "Write")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        let id = display.id
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = DDCController.shared.write(code: code, value: value, display: id)
            DispatchQueue.main.async {
                rawResult = ok ? "sent" : "write failed"
                // The write went around the controller: read the values again
                // so the sliders show what the monitor has now.
                if ok { controller.redetect() }
            }
        }
    }

    private func readAll() {
        let id = display.id
        report = "Reading…"
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            for vcp in DDCController.VCP.allCases where vcp.rawValue >= 0x10 {
                let name = vcp.name.padding(toLength: 14, withPad: " ", startingAt: 0)
                switch DDCController.shared.reading(code: vcp.rawValue, display: id) {
                case let .value(current, maximum):
                    lines.append(String(format: "0x%02X  %@ %d / %d", vcp.rawValue, name, current, maximum))
                case .unsupported:
                    lines.append(String(format: "0x%02X  %@ unsupported", vcp.rawValue, name))
                case .noReply:
                    lines.append(String(format: "0x%02X  %@ no reply", vcp.rawValue, name))
                }
            }
            DispatchQueue.main.async { report = lines.joined(separator: "\n") }
        }
    }
}

// MARK: - Application

struct ApplicationSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var sleep = SleepController.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var status: String?

    var body: some View {
        SettingsPage(title: "Application", subtitle: "Startup, behaviour, brightness method and diagnostics") {
            SettingsSectionTitle(title: "Startup")
            SettingsCard {
                SettingsToggleRow(title: "Launch at login", help: "Starts Great Display when you log in.", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in updateLoginItem(newValue) }
                SettingsRowDivider()
                SettingsToggleRow(title: "Restore display configuration on launch",
                                  help: "Re-applies saved resolutions, arrangement and main display.",
                                  isOn: $store.state.general.restoreConfigurationOnLaunch)
                if let status {
                    Text(status).font(.caption).foregroundStyle(.red).padding(.horizontal, SettingsStyle.rowInset).padding(.bottom, 8)
                }
            }
            SettingsSectionTitle(title: "Behaviour")
            SettingsCard {
                SettingsToggleRow(title: "Prevent sleep", help: "Keeps the Mac and its displays awake while Great Display runs.",
                                  isOn: Binding(get: { sleep.isPreventingSleep }, set: { sleep.setPreventSleep($0) }))
                SettingsRowDivider()
                SettingsToggleRow(title: "Reconnect disconnected displays when quitting",
                                  isOn: $store.state.general.reconnectDisplaysOnQuit)
            }
            SettingsSectionTitle(title: "Brightness")
            SettingsCard {
                SettingsToggleRow(title: "Color-table adjustments",
                                  help: "Software dimming and image adjustments scale the display's color table. Works on every display but can clip HDR content.",
                                  isOn: $store.state.general.softwareDimmingEnabled)
                SettingsRowDivider()
                SettingsToggleRow(title: "Combined brightness",
                                  help: "One brightness control that continues with software dimming below the hardware minimum.",
                                  isOn: $store.state.general.combinedBrightness,
                                  enabled: store.state.general.softwareDimmingEnabled)
            }
            SettingsSectionTitle(title: "Streaming")
            SettingsCard {
                SettingsRow(title: "Screen Recording",
                            value: FullScreenStreamController.shared.hasScreenRecordingPermission ? "Granted" : "Not granted",
                            help: "Streaming captures a display into a window on another display. macOS requires Screen Recording permission and an app relaunch after granting it.")
                SettingsRowDivider()
                SettingsButtonRow {
                    Button("Open Screen Recording Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
            SettingsSectionTitle(title: "Diagnostics")
            SettingsCard {
                SettingsRow(title: "DDC/CI transport", value: DDCController.shared.isSupported ? "Available" : "Unavailable")
                SettingsRowDivider()
                SettingsRow(title: "DisplayServices client", value: BrightnessEngine.shared.hasDisplayServices ? "Available" : "Unavailable")
                SettingsRowDivider()
                SettingsRow(title: "Display connection control", value: DisplayManager.shared.canDisconnect ? "Available" : "Unavailable")
                SettingsRowDivider()
                SettingsRow(title: "Virtual displays", value: VirtualScreenManager.shared.isSupported ? "Available" : "Unavailable")
            }
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        // Nothing to do when the switch already matches the system (this also
        // ends the change triggered by putting the switch back below).
        guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            store.state.general.launchAtLogin = enabled
            status = nil
        } catch {
            status = "Could not update the login item: \(error.localizedDescription)"
            // Show what is really registered, not what was asked for.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Menu

struct MenuSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        SettingsPage(title: "Menu", subtitle: "Contents, appearance and behaviour of the app menu") {
            SettingsSectionTitle(title: "Menu Contents")
            SettingsCard {
                SettingsToggleRow(title: "Resolution slider", help: "Shown on the first level under brightness.",
                                  isOn: $store.state.general.showResolutionSlider)
                SettingsRowDivider()
                SettingsToggleRow(title: "Contrast slider", help: "Hardware contrast over DDC, software contrast otherwise.",
                                  isOn: $store.state.general.showContrastSlider)
                SettingsRowDivider()
                SettingsToggleRow(title: "Volume slider", help: "For monitors with speakers controlled over DDC.",
                                  isOn: $store.state.general.showVolumeSlider)
                SettingsRowDivider()
                SettingsToggleRow(title: "Quit button", isOn: $store.state.general.showQuitButton)
            }
            SettingsSectionTitle(title: "Appearance and Behaviour")
            SettingsCard {
                SettingsToggleRow(title: "Close other displays when opening one", isOn: $store.state.general.singleExpandedSection)
                SettingsRowDivider()
                SettingsToggleRow(title: "Show the device header with a single display", isOn: $store.state.general.alwaysShowDeviceHeader)
                SettingsRowDivider()
                SettingsToggleRow(title: "Show brightness percentage in the menu bar", isOn: $store.state.general.menuBarShowsPercentage)
            }
            SettingsSectionTitle(title: "Resolution Slider and Display Mode Menu")
            SettingsCard {
                SettingsToggleRow(title: "Hide resolutions below 720 pixels high", isOn: $store.state.general.hideLowResolutions)
                SettingsRowDivider()
                SettingsToggleRow(title: "Fade the display when changing resolution",
                                  help: "Only the display being changed fades out and back in.",
                                  isOn: $store.state.general.fadeOnModeChange,
                                  enabled: store.state.general.softwareDimmingEnabled)
            }
            SettingsSectionTitle(title: "Menu Bar Icon")
            SettingsCard {
                SettingsHelpText(text: "Click to open the menu · Option-click opens Settings · Right-click opens the quick menu.")
            }
        }
    }
}

// MARK: - Keyboard

struct KeyboardSettingsView: View {
    @ObservedObject private var store = SettingsStore.shared
    @ObservedObject private var keyboard = KeyboardController.shared
    @State private var resetNote: String?

    var body: some View {
        SettingsPage(title: "Keyboard", subtitle: "Brightness and volume keys, adjustment steps and on-screen feedback") {
            SettingsSectionTitle(title: "Native Keyboard Control")
            SettingsCard {
                SettingsToggleRow(title: "Control displays with the brightness keys",
                                  help: "Also handles F14/F15 on PC keyboards. Volume keys control the monitor's DDC volume when audio plays through it.",
                                  isOn: $store.state.general.handleBrightnessKeys)
                    .onChange(of: store.state.general.handleBrightnessKeys) { _, enabled in
                        if enabled { _ = keyboard.start() } else { keyboard.stop() }
                    }
                SettingsRowDivider()
                SettingsIconHeader(symbol: keyboard.trusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill",
                                   title: "Accessibility access",
                                   tint: keyboard.trusted ? .green : .orange,
                                   subtitle: keyboard.trusted
                                       ? (keyboard.isTapRunning ? "Granted · keys active" : "Granted")
                                       : "Not active for this copy of Great Display")
                if !keyboard.trusted {
                    SettingsHelpText(text: "Already switched on in System Settings? That entry belongs to an earlier build. Reset it, then switch Great Display on again when macOS asks.")
                    if let resetNote {
                        Text(resetNote).font(.caption).foregroundStyle(.secondary).padding(.horizontal, SettingsStyle.rowInset)
                    }
                    SettingsButtonRow {
                        Button("Reset Permission") {
                            keyboard.resetAccessibilityPermission(bundleIdentifier: Bundle.main.bundleIdentifier ?? "app.greatdisplay.GreatDisplay")
                            _ = keyboard.requestAccess()
                            resetNote = "Permission reset. Enable Great Display in the dialog or in System Settings."
                        }
                        Button("Open Privacy Settings") {
                            _ = keyboard.requestAccess()
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
            if !keyboard.conflictingApps.isEmpty {
                let names = keyboard.conflictingApps.compactMap(\.localizedName).joined(separator: " and ")
                SettingsSectionTitle(title: "Conflict")
                SettingsCard {
                    SettingsIconHeader(symbol: "exclamationmark.triangle.fill",
                                       title: "\(names) is also controlling the brightness keys",
                                       tint: .orange,
                                       subtitle: "Only one app can handle them; the other never sees the key press.")
                    SettingsHelpText(text: "Quit \(names), or turn off its keyboard brightness control, to let Great Display handle the keys.")
                    SettingsButtonRow {
                        ForEach(keyboard.conflictingApps, id: \.processIdentifier) { app in
                            Button("Quit \(app.localizedName ?? "App")") {
                                app.terminate()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { keyboard.refreshConflicts() }
                            }
                        }
                    }
                }
            }
            SettingsSectionTitle(title: "Adjustment Steps")
            SettingsCard {
                SettingsSliderRow(title: "Brightness step", value: $store.state.general.brightnessStep, range: 0.01...0.25,
                                  text: "\(Int((store.state.general.brightnessStep * 100).rounded()))%")
            }
            SettingsSectionTitle(title: "OSD")
            SettingsCard {
                SettingsToggleRow(title: "Show on-screen feedback", isOn: $store.state.general.showOSD)
                SettingsRowDivider()
                SettingsSliderRow(title: "Visible for", value: $store.state.general.osdDuration, range: 0.5...4,
                                  text: String(format: "%.1f s", store.state.general.osdDuration))
                    .disabled(!store.state.general.showOSD)
            }
        }
        .onAppear { keyboard.checkTrust() }
    }
}

// MARK: - About

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        SettingsPage(title: "About") {
            SettingsCard {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Great Display").font(.title2.weight(.semibold))
                        Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                        Text("A menu bar display manager for macOS: resolution, HiDPI, brightness, DDC/CI, image adjustments and virtual screens.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(SettingsStyle.rowInset)
            }
            SettingsCard {
                SettingsHelpText(text: "Independent implementation. Uses public display APIs plus system-private display services resolved at runtime; those can change between macOS releases.")
            }
        }
    }
}
