import SwiftUI
import AppKit

// Building blocks for the app menu. The look follows a native macOS menu:
// 13 pt rows, rounded hover highlight, section headers with a trailing switch,
// and Control Center–style capsule sliders.

enum MenuMetrics {
    static let width: CGFloat = 320
    static let rowHeight: CGFloat = 24
    static let horizontalInset: CGFloat = 6
    static let contentInset: CGFloat = 10
    static let sliderHeight: CGFloat = 22
}

// MARK: - Slider

struct SliderMarker: Identifiable {
    let position: Double
    let label: String
    var id: String { "\(label)-\(position)" }
}

/// A thick capsule slider with the symbol drawn inside the track.
///
/// - Values update live while dragging unless `commitOnRelease` is set, in which
///   case `onCommit` fires once on release (used for the resolution slider).
/// - The knob snaps to nearby markers; holding Option bypasses snapping.
struct CapsuleSlider: View {
    @Binding var value: Double
    var symbol: String
    var markers: [SliderMarker] = []
    var steps: Int? = nil
    var trailingText: String? = nil
    var tint: Color = .white
    var height: CGFloat = MenuMetrics.sliderHeight
    var onSymbolTap: (() -> Void)? = nil
    var commitOnRelease = false
    var onCommit: ((Double) -> Void)? = nil
    var onDragChange: ((Double?) -> Void)? = nil

    @State private var dragValue: Double?
    @State private var isDragging = false
    @Environment(\.colorScheme) private var colorScheme

    private var shown: Double { dragValue ?? value }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knob = height
            let fillWidth = knob + (width - knob) * shown
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10))
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(knob, fillWidth))
                    .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0.5, y: 0)
                    // Glide when the value changes from outside (a mode that
                    // finished applying, brightness keys); track 1:1 while dragging.
                    .animation(isDragging ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: shown)
                ForEach(markers) { marker in
                    Rectangle()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 1.5, height: height * 0.36)
                        .offset(x: knob / 2 + (width - knob) * marker.position - 0.75)
                        .help(marker.label)
                }
                symbolView
                    .frame(width: knob, height: knob)
                if let trailingText {
                    // Two copies: secondary over the empty track, dark over the
                    // filled part, so the value stays readable as the fill passes.
                    ZStack {
                        trailingLabel(trailingText)
                            .foregroundStyle(.secondary)
                        trailingLabel(trailingText)
                            .foregroundStyle(Color.black.opacity(0.62))
                            .mask(alignment: .leading) {
                                Rectangle()
                                    .frame(width: max(knob, fillWidth))
                                    .animation(isDragging ? nil : .spring(response: 0.32, dampingFraction: 0.88), value: shown)
                            }
                    }
                    .animation(.easeOut(duration: 0.18), value: trailingText)
                    .allowsHitTesting(false)
                }
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging { isDragging = true }
                        let raw = (gesture.location.x - knob / 2) / max(1, width - knob)
                        let next = quantize(max(0, min(1, raw)))
                        if commitOnRelease {
                            dragValue = next
                            onDragChange?(next)
                        } else if abs(next - value) > 0.0001 {
                            value = next
                        }
                    }
                    .onEnded { _ in
                        if commitOnRelease, let final = dragValue {
                            onCommit?(final)
                        }
                        dragValue = nil
                        onDragChange?(nil)
                        isDragging = false
                    }
            )
        }
        .frame(height: height)
    }

    private var fillColor: Color {
        colorScheme == .dark ? tint.opacity(0.92) : Color.white
    }

    private func trailingLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .medium).monospacedDigit())
            .contentTransition(.numericText())
            .lineLimit(1)
            .padding(.trailing, 9)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var symbolView: some View {
        let image = Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.black.opacity(0.62))
        if let onSymbolTap {
            Button(action: onSymbolTap) { image.frame(width: height, height: height) }
                .buttonStyle(.plain)
        } else {
            image.allowsHitTesting(false)
        }
    }

    private func quantize(_ raw: Double) -> Double {
        if let steps, steps > 0 {
            return (raw * Double(steps)).rounded() / Double(steps)
        }
        if !NSEvent.modifierFlags.contains(.option),
           let near = markers.min(by: { abs($0.position - raw) < abs($1.position - raw) }),
           abs(near.position - raw) < 0.025 {
            return near.position
        }
        return raw
    }
}

/// Slider row: capsule slider with an optional caption above.
struct SliderRow: View {
    var title: String? = nil
    @Binding var value: Double
    var symbol: String
    var markers: [SliderMarker] = []
    var trailingText: String? = nil
    var onSymbolTap: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)
            }
            CapsuleSlider(value: $value, symbol: symbol, markers: markers,
                          trailingText: trailingText, onSymbolTap: onSymbolTap)
        }
        .padding(.horizontal, MenuMetrics.contentInset)
        .padding(.vertical, 3)
    }
}

// MARK: - Rows

/// Hover-highlighted menu row.
struct MenuRow<Trailing: View>: View {
    var symbol: String?
    var title: String
    var subtitle: String? = nil
    var checked: Bool = false
    var enabled: Bool = true
    var indent: CGFloat = 0
    var action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 14)
                } else if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 12))
                        .frame(width: 14)
                        .foregroundStyle(hovering && enabled ? Color.white : Color.secondary)
                } else {
                    Color.clear.frame(width: 14, height: 1)
                }
                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(hovering && enabled ? Color.white.opacity(0.8) : Color.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                trailing()
                    .foregroundStyle(hovering && enabled ? Color.white.opacity(0.85) : Color.secondary)
            }
            .padding(.leading, 8 + indent)
            .padding(.trailing, 8)
            .frame(height: MenuMetrics.rowHeight)
            .foregroundStyle(hovering && enabled ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(hovering && enabled ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .padding(.horizontal, MenuMetrics.horizontalInset)
        .onHover { hovering = $0 }
    }
}

extension MenuRow where Trailing == EmptyView {
    init(symbol: String?, title: String, subtitle: String? = nil, checked: Bool = false,
         enabled: Bool = true, indent: CGFloat = 0, action: @escaping () -> Void) {
        self.init(symbol: symbol, title: title, subtitle: subtitle, checked: checked,
                  enabled: enabled, indent: indent, action: action, trailing: { EmptyView() })
    }
}

/// A row that expands a feature section inline (the sidebar-style presentation
/// of a submenu). Shows the current value and a rotating chevron.
struct FeatureRow: View {
    var symbol: String
    var title: String
    var value: String?
    var isExpanded: Bool
    var enabled: Bool = true
    var toggle: () -> Void

    var body: some View {
        MenuRow(symbol: symbol, title: title, enabled: enabled, action: {
            withAnimation(.easeInOut(duration: 0.16)) { toggle() }
        }) {
            HStack(spacing: 5) {
                if let value {
                    Text(value)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: value)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
        }
    }
}

/// Container for an expanded feature: slightly recessed background.
struct FeaturePanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
        .padding(.horizontal, MenuMetrics.horizontalInset + 2)
        .padding(.vertical, 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

/// Section caption inside menus, e.g. "Default and native modes".
struct MenuCaption: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, MenuMetrics.contentInset + 4)
            .padding(.top, 5)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MenuDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, MenuMetrics.contentInset + 2)
            .padding(.vertical, 4)
    }
}

/// Small rounded tag used for aspect ratio / refresh / density.
struct TagView: View {
    var text: String
    var color: Color = .secondary
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 4)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(color.opacity(0.18)))
            .foregroundStyle(color)
    }
}

/// Filter chip that toggles on click.
struct ChipToggle: View {
    var title: String
    var isOn: Bool
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(isOn ? Color.accentColor : Color.primary.opacity(0.08)))
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

/// Header for a device section: icon, name, badges, trailing switch.
struct DeviceHeader: View {
    var symbol: String
    var name: String
    var subtitle: String?
    var badges: [String]
    var isExpanded: Bool
    var isConnected: Bool
    var switchEnabled: Bool
    var onToggleExpand: () -> Void
    var onSwitch: (Bool) -> Void
    var onOptionClick: (() -> Void)? = nil

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                if NSEvent.modifierFlags.contains(.option), let onOptionClick {
                    onOptionClick()
                } else {
                    withAnimation(.easeInOut(duration: 0.16)) { onToggleExpand() }
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(isConnected ? Color.accentColor : Color.primary.opacity(0.12))
                            .frame(width: 26, height: 26)
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(isConnected ? Color.white : Color.secondary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Text(name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            ForEach(badges, id: \.self) { badge in
                                Text(badge)
                                    .font(.system(size: 8.5, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.primary.opacity(0.14)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.2), value: subtitle)
                        }
                    }
                    Spacer(minLength: 4)
                    if isConnected {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .opacity(hovering ? 1 : 0.6)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Toggle("", isOn: Binding(get: { isConnected }, set: onSwitch))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(!switchEnabled)
                .help(isConnected ? "Disconnect" : "Connect")
        }
        .padding(.horizontal, MenuMetrics.contentInset + 2)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(hovering ? Color.primary.opacity(0.05) : Color.clear)
                .padding(.horizontal, MenuMetrics.horizontalInset)
        )
        .onHover { hovering = $0 }
    }
}

/// The small centred chevron that reveals a section's additional options.
struct MoreOptionsChevron: View {
    var isOpen: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) { action() }
        } label: {
            Image(systemName: "chevron.compact.down")
                .font(.system(size: 15, weight: .medium))
                .rotationEffect(.degrees(isOpen ? 180 : 0))
                .foregroundStyle(hovering ? Color.primary : Color.secondary.opacity(0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(isOpen ? "Fewer options" : "More options")
        .onHover { hovering = $0 }
    }
}
