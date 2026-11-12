import SwiftUI
import AppKit
import GDCore

// Building blocks for the Settings window: a translucent sidebar, a grey
// device bar, and grouped cards whose rows carry a title, optional help text
// (hidden when "Show help" is off) and a trailing control.

enum SettingsStyle {
    static let contentBackground = Color(nsColor: .textBackgroundColor)
    static let cardFill = Color.primary.opacity(0.035)
    static let cardStroke = Color.primary.opacity(0.07)
    static let rowInset: CGFloat = 16
}

/// NSVisualEffectView wrapper for the sidebar and header materials.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
    }
}

/// Rounded, lightly filled group of rows.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(SettingsStyle.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(SettingsStyle.cardStroke))
    }
}

/// Bold section title above a card ("General Settings", "Device Control").
struct SettingsSectionTitle: View {
    var title: String
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .padding(.leading, SettingsStyle.rowInset)
            .padding(.top, 14)
            .padding(.bottom, 2)
    }
}

/// Divider between rows, inset to the row content.
struct SettingsRowDivider: View {
    var body: some View {
        Divider().padding(.horizontal, SettingsStyle.rowInset)
    }
}

/// Title (+ optional help) on the left, any control on the right.
struct SettingsRow<Trailing: View>: View {
    var title: String
    var help: String? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13))
                if let help, store.state.general.showHelp {
                    Text(help)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            trailing()
        }
        .padding(.horizontal, SettingsStyle.rowInset)
        .padding(.vertical, 9)
    }
}

extension SettingsRow where Trailing == Text {
    /// Read-only value row ("Display name … DELL S2725QC").
    init(title: String, value: String, help: String? = nil) {
        self.title = title
        self.help = help
        self.trailing = { Text(value).font(.system(size: 13)).foregroundStyle(.secondary) }
    }
}

/// Row with a trailing switch.
struct SettingsToggleRow: View {
    var title: String
    var help: String? = nil
    @Binding var isOn: Bool
    var enabled: Bool = true

    var body: some View {
        SettingsRow(title: title, help: help) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!enabled)
        }
        .opacity(enabled ? 1 : 0.55)
    }
}

/// Row with a slider and its value.
struct SettingsSliderRow: View {
    var title: String
    var help: String? = nil
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var text: String

    var body: some View {
        SettingsRow(title: title, help: help) {
            HStack(spacing: 10) {
                Slider(value: $value, in: range).frame(width: 240)
                Text(text)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
        }
    }
}

/// Right-aligned row of buttons at the bottom of a card.
struct SettingsButtonRow<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            content()
        }
        .controlSize(.large)
        .padding(.horizontal, SettingsStyle.rowInset)
        .padding(.vertical, 8)
    }
}

/// Card header with a tinted icon tile ("DDC Control", "Configure Device Control").
struct SettingsIconHeader<Trailing: View>: View {
    var symbol: String
    var title: String
    var tint: Color = .accentColor
    var subtitle: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, SettingsStyle.rowInset)
        .padding(.vertical, 10)
    }
}

extension SettingsIconHeader where Trailing == EmptyView {
    init(symbol: String, title: String, tint: Color = .accentColor, subtitle: String? = nil) {
        self.init(symbol: symbol, title: title, tint: tint, subtitle: subtitle, trailing: { EmptyView() })
    }
}

struct IconTile: View {
    var symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(.white)
            )
            .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
    }
}

/// Explanatory paragraph inside a card (shown only with "Show help").
struct SettingsHelpText: View {
    var text: String
    @ObservedObject private var store = SettingsStore.shared

    var body: some View {
        if store.state.general.showHelp {
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SettingsStyle.rowInset)
                .padding(.vertical, 6)
        }
    }
}

/// Page scaffold for panes without a device bar: large title, then cards.
struct SettingsPage<Content: View>: View {
    var title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 22, weight: .bold))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 4)
                .padding(.bottom, 6)
                content()
            }
            .padding(.horizontal, 32)
            .padding(.top, 44)
            .padding(.bottom, 28)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Upward-pointing notch drawn under the selected device in the device bar.
struct NotchTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
