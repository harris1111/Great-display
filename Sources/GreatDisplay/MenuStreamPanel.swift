import SwiftUI
import AppKit
import GDCore

/// The "Stream Display" panel in the app menu: targets, then the saved stream
/// options for this source display, applied live to a running stream.
struct StreamPanel: View {
    let display: DisplayInfo
    @ObservedObject private var controller = DisplayController.shared
    @ObservedObject private var streams = FullScreenStreamController.shared
    @ObservedObject private var store = SettingsStore.shared
    @State private var showFilters = false

    private var configuration: StreamConfiguration { streams.configuration(forSource: display) }
    private var current: FullScreenStreamController.ActiveStream? { streams.stream(for: display.id) }

    private func edit(_ change: (inout StreamConfiguration) -> Void) {
        var copy = configuration
        change(&copy)
        streams.update(copy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MenuCaption(text: "Stream the contents of this display to:")
            MenuRow(symbol: "rectangle.on.rectangle.angled", title: "Self-Stream + Video Filters",
                    checked: current?.isSelfStream == true) {
                toggleStream(to: display)
            }
            ForEach(controller.displays.filter { $0.id != display.id }) { other in
                MenuRow(symbol: DisplayGlyph.symbol(for: other), title: other.name, checked: current?.target == other.id) {
                    toggleStream(to: other)
                } trailing: {
                    if other.isMain { TagView(text: "M") }
                }
            }
            MenuDivider()
            MenuRow(symbol: "stop.fill", title: "Stop Streaming", enabled: current != nil) {
                streams.stop(source: display.id)
            }
            MenuRow(symbol: "arrowshape.turn.up.right.fill", title: "Resume Stream on Connect",
                    checked: configuration.resumeOnConnect) {
                edit { $0.resumeOnConnect.toggle() }
            }
            MenuRow(symbol: "cursorarrow.click.2", title: "Use Like a Normal Screen",
                    checked: configuration.interactive) {
                edit { $0.interactive.toggle() }
            }
            .help("The pointer moves onto this display when it enters the stream: click, type, scroll and use its menu bar through the stream.")
            if !streams.hasScreenRecordingPermission {
                MenuRow(symbol: "lock.shield", title: "Grant Screen Recording…") {
                    streams.requestScreenRecordingPermission()
                }
            }
            if let error = streams.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 3)
            }
            MenuDivider()

            OptionRow(symbol: "cursorarrow.rays", title: "Show Mouse Pointer", isOn: configuration.showCursor) {
                edit { $0.showCursor.toggle() }
            }
            OptionRow(symbol: "number", title: "1:1 Pixel Mapping", isOn: configuration.scaling == .pixelPerfect) {
                edit { $0.scaling = $0.scaling == .pixelPerfect ? .fit : .pixelPerfect }
            }
            OptionRow(symbol: "checkerboard.rectangle", title: "Integer Scaling", isOn: configuration.scaling == .integer) {
                edit { $0.scaling = $0.scaling == .integer ? .fit : .integer }
            }
            OptionRow(symbol: "rectangle.expand.vertical", title: "Free Aspect Ratio", isOn: configuration.scaling == .fill) {
                edit { $0.scaling = $0.scaling == .fill ? .fit : .fill }
            }
            OptionRow(symbol: "camera.filters", title: "Video Filters", isOn: configuration.filter != .none,
                      detail: configuration.filter == .none ? nil : configuration.filter.title) {
                withAnimation(.easeInOut(duration: 0.15)) { showFilters.toggle() }
            }
            if showFilters {
                FeaturePanel {
                    ForEach(StreamConfiguration.VideoFilter.allCases, id: \.self) { filter in
                        MenuRow(symbol: nil, title: filter.title, checked: configuration.filter == filter) {
                            edit { $0.filter = filter }
                        }
                    }
                }
            }
            OptionRow(symbol: "crop", title: "Enable Cropping", isOn: configuration.cropEnabled) {
                edit { $0.cropEnabled.toggle() }
            }
            if configuration.cropEnabled {
                cropSliders
            }

            HStack(spacing: 8) {
                OptionBox(title: "Flip") {
                    CircleIconButton(symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                                     selected: configuration.flipHorizontal, help: "Flip horizontally") {
                        edit { $0.flipHorizontal.toggle() }
                    }
                    CircleIconButton(symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                                     selected: configuration.flipVertical, help: "Flip vertically") {
                        edit { $0.flipVertical.toggle() }
                    }
                }
                OptionBox(title: "Rotate") {
                    CircleIconButton(symbol: "arrow.uturn.left", selected: configuration.rotation == 270, help: "Rotate left") {
                        edit { $0.rotation = $0.rotation == 270 ? 0 : 270 }
                    }
                    CircleIconButton(symbol: "arrow.down", selected: configuration.rotation == 180, help: "Upside down") {
                        edit { $0.rotation = $0.rotation == 180 ? 0 : 180 }
                    }
                    CircleIconButton(symbol: "arrow.uturn.right", selected: configuration.rotation == 90, help: "Rotate right") {
                        edit { $0.rotation = $0.rotation == 90 ? 0 : 90 }
                    }
                    CircleIconButton(symbol: "nosign", selected: false, help: "No rotation") {
                        edit { $0.rotation = 0 }
                    }
                    .opacity(configuration.rotation == 0 ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            HStack(spacing: 8) {
                OptionBox(title: "Vertical") {
                    CircleIconButton(symbol: "align.vertical.top", selected: configuration.vertical == .top, help: "Top") {
                        edit { $0.vertical = .top }
                    }
                    CircleIconButton(symbol: "align.vertical.center", selected: configuration.vertical == .center, help: "Center") {
                        edit { $0.vertical = .center }
                    }
                    CircleIconButton(symbol: "align.vertical.bottom", selected: configuration.vertical == .bottom, help: "Bottom") {
                        edit { $0.vertical = .bottom }
                    }
                }
                OptionBox(title: "Horizontal") {
                    CircleIconButton(symbol: "align.horizontal.left", selected: configuration.horizontal == .left, help: "Left") {
                        edit { $0.horizontal = .left }
                    }
                    CircleIconButton(symbol: "align.horizontal.center", selected: configuration.horizontal == .center, help: "Center") {
                        edit { $0.horizontal = .center }
                    }
                    CircleIconButton(symbol: "align.horizontal.right", selected: configuration.horizontal == .right, help: "Right") {
                        edit { $0.horizontal = .right }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            labelledSlider("Zoom", symbol: "plus.magnifyingglass",
                           tag: String(format: "%.1fx", configuration.zoom),
                           value: (configuration.zoom - 1) / 3,
                           marker: 0) { value in edit { $0.zoom = 1 + value * 3 } }
            labelledSlider("Underscan", symbol: "arrow.down.right.and.arrow.up.left",
                           tag: configuration.underscan >= 0.999 ? "Original" : nil,
                           text: "\(Int((configuration.underscan * 100).rounded()))%",
                           value: (configuration.underscan - 0.5) / 0.5,
                           marker: 1) { value in edit { $0.underscan = 0.5 + value * 0.5 } }
            labelledSlider("Alpha", symbol: "square.dashed",
                           text: "\(Int((configuration.alpha * 100).rounded()))%",
                           value: (configuration.alpha - 0.1) / 0.9) { value in edit { $0.alpha = 0.1 + value * 0.9 } }
            let rates = [15, 24, 30, 60, 120, 0]
            let rateIndex = rates.firstIndex(of: configuration.targetFPS) ?? rates.count - 1
            labelledSlider("Target FPS", symbol: "gauge.with.dots.needle.67percent",
                           text: configuration.targetFPS == 0 ? "∞" : "\(configuration.targetFPS)",
                           value: Double(rateIndex) / Double(rates.count - 1),
                           steps: rates.count - 1) { value in
                edit { $0.targetFPS = rates[Int((value * Double(rates.count - 1)).rounded())] }
            }
        }
        .padding(.bottom, 4)
    }

    private var cropSliders: some View {
        VStack(spacing: 0) {
            labelledSlider("Crop Top", symbol: "arrow.down.to.line", text: "\(Int(configuration.cropTop * 100))%",
                           value: configuration.cropTop / 0.45) { value in edit { $0.cropTop = value * 0.45 } }
            labelledSlider("Crop Bottom", symbol: "arrow.up.to.line", text: "\(Int(configuration.cropBottom * 100))%",
                           value: configuration.cropBottom / 0.45) { value in edit { $0.cropBottom = value * 0.45 } }
            labelledSlider("Crop Left", symbol: "arrow.right.to.line", text: "\(Int(configuration.cropLeft * 100))%",
                           value: configuration.cropLeft / 0.45) { value in edit { $0.cropLeft = value * 0.45 } }
            labelledSlider("Crop Right", symbol: "arrow.left.to.line", text: "\(Int(configuration.cropRight * 100))%",
                           value: configuration.cropRight / 0.45) { value in edit { $0.cropRight = value * 0.45 } }
        }
    }

    private func labelledSlider(_ title: String, symbol: String, tag: String? = nil, text: String? = nil,
                                value: Double, marker: Double? = nil, steps: Int? = nil,
                                set: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                if let tag { TagView(text: tag, color: .accentColor) }
                if let text { Text(text).font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary) }
            }
            CapsuleSlider(value: Binding(get: { max(0, min(1, value)) }, set: set),
                          symbol: symbol,
                          markers: marker.map { [SliderMarker(position: $0, label: title)] } ?? [],
                          steps: steps,
                          height: 18)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
    }

    private func toggleStream(to target: DisplayInfo) {
        if current?.target == target.id {
            streams.stop(source: display.id)
            return
        }
        Task { @MainActor in
            let started = await streams.start(source: display.id, on: target.id)
            if !started, let message = streams.lastError {
                let alert = NSAlert()
                alert.messageText = "Cannot start the stream"
                alert.informativeText = message
                alert.alertStyle = .warning
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
    }
}

/// Menu row with a round icon that turns accent-filled when on.
private struct OptionRow: View {
    let symbol: String
    let title: String
    let isOn: Bool
    var detail: String? = nil
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                ZStack {
                    Circle().fill(isOn ? Color.accentColor : Color.primary.opacity(0.1)).frame(width: 22, height: 22)
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(isOn ? Color.white : Color.primary.opacity(0.75))
                }
                Text(title).font(.system(size: 13))
                Spacer()
                if let detail {
                    Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 5).fill(hovering ? Color.primary.opacity(0.07) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MenuMetrics.horizontalInset)
        .onHover { hovering = $0 }
    }
}

/// Rounded group with a title and a row of round buttons (Flip, Rotate, …).
private struct OptionBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.system(size: 11.5, weight: .medium)).foregroundStyle(.secondary)
            HStack(spacing: 8) { content() }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
    }
}

private struct CircleIconButton: View {
    let symbol: String
    let selected: Bool
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(selected ? Color.accentColor : Color.primary.opacity(0.1)).frame(width: 30, height: 30)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.8))
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
