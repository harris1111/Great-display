// Renders the short promo film shown on the website.
//
// Everything is drawn with CoreGraphics and encoded with AVFoundation, so the
// film can be regenerated on any Mac without third-party tools:
//
//   make promo-video
//
// or by hand, from the repository root:
//
//   swiftc -O Scripts/make_promo_video.swift -o .build/make_promo_video
//   .build/make_promo_video website/assets/great-display.mp4 \
//       --poster website/assets/great-display-poster.jpg 9.2
//   .build/make_promo_video --stills /tmp/stills 2,8,14   # PNG frames for review

import AppKit
import AVFoundation
import CoreText

let W = 1920, H = 1080
let FPS: Int32 = 30
let DURATION = 31.0
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

// MARK: - Math

func clamp01(_ x: CGFloat) -> CGFloat { min(max(x, 0), 1) }
/// Normalised progress of `t` through `a...b`.
func p(_ t: Double, _ a: Double, _ b: Double) -> CGFloat { clamp01(CGFloat((t - a) / (b - a))) }
func easeOut(_ x: CGFloat) -> CGFloat { 1 - pow(1 - x, 3) }
func easeIn(_ x: CGFloat) -> CGFloat { x * x * x }
func easeInOut(_ x: CGFloat) -> CGFloat { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
func easeOutBack(_ x: CGFloat) -> CGFloat {
    let c1: CGFloat = 1.30, c3 = c1 + 1
    return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
}
func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t)) }
func lerp(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
    CGRect(x: lerp(a.minX, b.minX, t), y: lerp(a.minY, b.minY, t),
           width: lerp(a.width, b.width, t), height: lerp(a.height, b.height, t))
}
/// 0 before `a`, eases to 1 over `fin`, holds, eases back to 0 over `fout` ending at `b`.
func envelope(_ t: Double, _ a: Double, _ b: Double, fin: Double = 0.5, fout: Double = 0.5) -> CGFloat {
    min(easeOut(p(t, a, a + fin)), 1 - easeIn(p(t, b - fout, b)))
}
/// Piecewise keyframes with ease-in-out between them.
func track(_ t: Double, _ keys: [(Double, CGFloat)]) -> CGFloat {
    guard let first = keys.first else { return 0 }
    if t <= first.0 { return first.1 }
    for i in 1..<keys.count where t <= keys[i].0 {
        return lerp(keys[i - 1].1, keys[i].1, easeInOut(p(t, keys[i - 1].0, keys[i].0)))
    }
    return keys.last!.1
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
func white(_ a: CGFloat) -> NSColor { NSColor(srgbRed: 1, green: 1, blue: 1, alpha: a) }
func black(_ a: CGFloat) -> NSColor { NSColor(srgbRed: 0, green: 0, blue: 0, alpha: a) }

let accent = rgb(0x0A84FF)
let headlineGradient = [rgb(0x64D2FF), rgb(0x0A84FF), rgb(0xBF5AF2)]

// MARK: - Drawing primitives (top-left origin, y down)

var ctx: CGContext!

func withAlpha(_ a: CGFloat, _ body: () -> Void) {
    guard a > 0.002 else { return }
    if a >= 0.998 { body(); return }
    ctx.saveGState()
    ctx.setAlpha(a)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func scaled(_ s: CGFloat, about c: CGPoint, _ body: () -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: c.x, y: c.y)
    ctx.scaleBy(x: s, y: s)
    ctx.translateBy(x: -c.x, y: -c.y)
    body()
    ctx.restoreGState()
}

func roundPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    let rr = max(0, min(radius, min(r.width, r.height) / 2 - 0.001))
    return CGPath(roundedRect: r, cornerWidth: rr, cornerHeight: rr, transform: nil)
}

func fillRound(_ r: CGRect, _ radius: CGFloat, _ color: NSColor) {
    ctx.addPath(roundPath(r, radius))
    ctx.setFillColor(color.cgColor)
    ctx.fillPath()
}

func strokeRound(_ r: CGRect, _ radius: CGFloat, _ color: NSColor, _ width: CGFloat, dash: [CGFloat]? = nil) {
    ctx.saveGState()
    ctx.addPath(roundPath(r, radius))
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    if let dash { ctx.setLineDash(phase: 0, lengths: dash) }
    ctx.strokePath()
    ctx.restoreGState()
}

func shadowed(_ blur: CGFloat, _ dy: CGFloat, _ color: NSColor, _ body: () -> Void) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: dy), blur: blur, color: color.cgColor)
    body()
    ctx.restoreGState()
}

func gradient(_ colors: [NSColor], _ locations: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: srgb, colors: colors.map(\.cgColor) as CFArray, locations: locations)!
}

func glow(_ center: CGPoint, _ radius: CGFloat, _ color: NSColor) {
    ctx.drawRadialGradient(gradient([color, color.withAlphaComponent(0)]),
                           startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
}

// MARK: - Text

func kern(_ size: CGFloat) -> CGFloat { size >= 40 ? -size * 0.024 : (size >= 20 ? -size * 0.01 : 0) }

func font(_ size: CGFloat, _ weight: NSFont.Weight, mono: Bool = false) -> NSFont {
    mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
}

enum Align { case left, center, right }

/// Draws a single line; `pt.y` is the vertical centre of the line.
@discardableResult
func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, at pt: CGPoint,
          align: Align = .center, mono: Bool = false) -> CGFloat {
    let a = NSAttributedString(string: s, attributes: [
        .font: font(size, weight, mono: mono), .foregroundColor: color, .kern: kern(size),
    ])
    let sz = a.size()
    var x = pt.x
    if align == .center { x -= sz.width / 2 } else if align == .right { x -= sz.width }
    a.draw(at: CGPoint(x: x, y: pt.y - sz.height / 2))
    return sz.width
}

/// Headline filled with a horizontal gradient, centred on `center`.
func gradientText(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, _ colors: [NSColor], center: CGPoint) {
    let a = NSAttributedString(string: s, attributes: [.font: font(size, weight), .kern: kern(size)])
    let line = CTLineCreateWithAttributedString(a)
    var asc: CGFloat = 0, desc: CGFloat = 0, lead: CGFloat = 0
    let w = CGFloat(CTLineGetTypographicBounds(line, &asc, &desc, &lead))
    let x0 = center.x - w / 2
    let baseline = center.y + (asc - desc) / 2
    // Build the glyph outlines (flipped for the y-down canvas) and clip to them.
    let outline = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let attributes = CTRunGetAttributes(run) as NSDictionary
        let runFont = attributes[kCTFontAttributeName as String] as! CTFont
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for i in 0..<count {
            guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) else { continue }
            let transform = CGAffineTransform(translationX: x0 + positions[i].x, y: baseline - positions[i].y)
                .scaledBy(x: 1, y: -1)
            outline.addPath(glyph, transform: transform)
        }
    }
    ctx.saveGState()
    ctx.addPath(outline)
    ctx.clip()
    ctx.drawLinearGradient(gradient(colors), start: CGPoint(x: x0, y: 0), end: CGPoint(x: x0 + w, y: 0), options: [])
    ctx.restoreGState()
}

// MARK: - Images

var symbolCache: [String: NSImage] = [:]

func symbol(_ name: String, _ size: CGFloat, _ weight: NSFont.Weight, _ color: NSColor, at c: CGPoint) {
    let key = "\(name)|\(size)|\(weight.rawValue)|\(color.description)"
    var image = symbolCache[key]
    if image == nil {
        let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        if image == nil { FileHandle.standardError.write("missing symbol \(name)\n".data(using: .utf8)!) }
        symbolCache[key] = image ?? NSImage()
    }
    guard let image, image.size.width > 0 else { return }
    let s = image.size
    image.draw(in: CGRect(x: c.x - s.width / 2, y: c.y - s.height / 2, width: s.width, height: s.height),
               from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

let appIcon: NSImage = {
    guard let image = NSImage(contentsOfFile: "docs/images/icon.png") else {
        fatalError("Run from the repository root (docs/images/icon.png not found)")
    }
    return image
}()

func drawIcon(center: CGPoint, size: CGFloat) {
    appIcon.draw(in: CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size),
                 from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true,
                 hints: [.interpolation: NSImageInterpolation.high.rawValue])
}

func makeWallpaper(_ base: [UInt32], _ blobs: [(CGFloat, CGFloat, CGFloat, UInt32, CGFloat)]) -> CGImage {
    let w = 1280, h = 800
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    c.drawLinearGradient(gradient(base.map { rgb($0) }), start: CGPoint(x: 0, y: CGFloat(h)),
                         end: CGPoint(x: CGFloat(w), y: 0), options: [])
    for (x, y, r, color, a) in blobs {
        let center = CGPoint(x: x * CGFloat(w), y: CGFloat(h) - y * CGFloat(h))
        c.drawRadialGradient(gradient([rgb(color, a), rgb(color, 0)]), startCenter: center, startRadius: 0,
                             endCenter: center, endRadius: r * CGFloat(w), options: [])
    }
    return c.makeImage()!
}

let wallpaperBlue = makeWallpaper([0x081229, 0x1B1F4B, 0x2C1A4F], [
    (0.18, 0.78, 0.55, 0x0A84FF, 0.55), (0.78, 0.25, 0.50, 0xBF5AF2, 0.45),
    (0.55, 0.62, 0.35, 0x64D2FF, 0.30), (0.95, 0.90, 0.40, 0x5E5CE6, 0.40),
])
let wallpaperWarm = makeWallpaper([0x1A0B1E, 0x3B1430, 0x4A1E1A], [
    (0.25, 0.30, 0.55, 0xFF375F, 0.45), (0.80, 0.70, 0.55, 0xFF9F0A, 0.45),
    (0.55, 0.45, 0.30, 0xBF5AF2, 0.35),
])
let wallpaperTeal = makeWallpaper([0x04161A, 0x0B2D33, 0x10243F], [
    (0.20, 0.70, 0.55, 0x30D158, 0.35), (0.75, 0.30, 0.55, 0x64D2FF, 0.45),
    (0.50, 0.90, 0.40, 0x0A84FF, 0.35),
])

func drawImage(_ image: CGImage, in r: CGRect) {
    ctx.saveGState()
    ctx.interpolationQuality = .high
    ctx.draw(image, in: r)
    ctx.restoreGState()
}

// MARK: - Interface pieces (drawn in points; callers scale)

func toggleSwitch(at origin: CGPoint, on: Bool) {
    let r = CGRect(x: origin.x, y: origin.y, width: 26, height: 15)
    fillRound(r, 7.5, on ? accent : white(0.16))
    shadowed(2, 0.5, black(0.3)) {
        let k = CGRect(x: on ? r.maxX - 14 : r.minX + 1, y: r.minY + 1, width: 13, height: 13)
        fillRound(k, 6.5, white(1))
    }
}

func capsuleSlider(_ r: CGRect, value: CGFloat, symbolName: String, trailing: String?, markers: [CGFloat] = []) {
    let knob = r.height
    let fillW = knob + (r.width - knob) * clamp01(value)
    let fillRect = CGRect(x: r.minX, y: r.minY, width: fillW, height: r.height)
    let labelAt = CGPoint(x: r.maxX - 9, y: r.midY)
    fillRound(r, r.height / 2, white(0.16))
    // The value reads light over the empty track and dark over the fill.
    if let trailing { text(trailing, 10.5, .medium, white(0.55), at: labelAt, align: .right, mono: true) }
    shadowed(3, 0, black(0.25)) { fillRound(fillRect, r.height / 2, white(0.93)) }
    if let trailing {
        ctx.saveGState()
        ctx.clip(to: fillRect)
        text(trailing, 10.5, .medium, black(0.62), at: labelAt, align: .right, mono: true)
        ctx.restoreGState()
    }
    for m in markers {
        let x = r.minX + knob / 2 + (r.width - knob) * m - 0.75
        ctx.setFillColor((x < r.minX + fillW ? black(0.28) : white(0.35)).cgColor)
        ctx.fill(CGRect(x: x, y: r.midY - r.height * 0.18, width: 1.5, height: r.height * 0.36))
    }
    symbol(symbolName, 11, .semibold, black(0.62), at: CGPoint(x: r.minX + knob / 2, y: r.midY))
}

func knobCenter(_ r: CGRect, _ value: CGFloat) -> CGPoint {
    CGPoint(x: r.minX + r.height / 2 + (r.width - r.height) * clamp01(value), y: r.midY)
}

func deviceHeader(y: CGFloat, symbolName: String, name: String, subtitle: String, connected: Bool,
                  badge: String? = nil, width: CGFloat = 320) {
    let cy = y + 18
    fillRound(CGRect(x: 9, y: cy - 13, width: 26, height: 26), 13, connected ? accent : white(0.12))
    symbol(symbolName, 12, .medium, connected ? white(1) : white(0.55), at: CGPoint(x: 22, y: cy))
    let nameW = text(name, 13, .semibold, white(0.95), at: CGPoint(x: 43, y: cy - 7), align: .left)
    if let badge {
        let bw = CGFloat(badge.count) * 5.6 + 8
        fillRound(CGRect(x: 43 + nameW + 5, y: cy - 13, width: bw, height: 12), 3, white(0.14))
        text(badge, 8.5, .bold, white(0.6), at: CGPoint(x: 43 + nameW + 5 + bw / 2, y: cy - 7))
    }
    text(subtitle, 10.5, .regular, white(0.55), at: CGPoint(x: 43, y: cy + 8), align: .left)
    if connected { symbol("chevron.right", 9, .bold, white(0.3), at: CGPoint(x: width - 52, y: cy)) }
    toggleSwitch(at: CGPoint(x: width - 38, y: cy - 7.5), on: connected)
}

func divider(y: CGFloat, width: CGFloat = 320) {
    ctx.setFillColor(white(0.1).cgColor)
    ctx.fill(CGRect(x: 12, y: y, width: width - 24, height: 1))
}

func menuBackground(_ size: CGSize) {
    shadowed(34, 14, black(0.5)) { fillRound(CGRect(origin: .zero, size: size), 12, rgb(0x232326, 0.94)) }
    strokeRound(CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5), 12, white(0.14), 1)
}

func cursor(at pt: CGPoint, scale s: CGFloat = 1.5, pressed: Bool = false) {
    ctx.saveGState()
    ctx.translateBy(x: pt.x, y: pt.y)
    ctx.scaleBy(x: s * (pressed ? 0.9 : 1), y: s * (pressed ? 0.9 : 1))
    let path = CGMutablePath()
    path.addLines(between: [CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 17), CGPoint(x: 4.2, y: 13.2), CGPoint(x: 7, y: 19.6),
                            CGPoint(x: 9.6, y: 18.5), CGPoint(x: 6.9, y: 12.3), CGPoint(x: 12.3, y: 12.3)])
    path.closeSubpath()
    shadowed(4, 1.5, black(0.45)) {
        ctx.addPath(path); ctx.setFillColor(black(1).cgColor); ctx.fillPath()
    }
    ctx.addPath(path)
    ctx.setStrokeColor(white(1).cgColor)
    ctx.setLineWidth(1.3)
    ctx.setLineJoin(.round)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Captions and scene helpers

func caption(_ t: Double, _ a: Double, _ b: Double, _ title: String, _ sub: String) {
    let e = envelope(t, a, b, fin: 0.6, fout: 0.45)
    guard e > 0 else { return }
    let rise = (1 - easeOut(p(t, a, a + 0.8))) * 18
    withAlpha(e) {
        text(title, 50, .bold, white(0.97), at: CGPoint(x: 960, y: 944 + rise))
        text(sub, 24, .regular, white(0.6), at: CGPoint(x: 960, y: 1000 + rise * 1.4))
    }
}

func screenBezel(_ r: CGRect, radius: CGFloat = 12, bezel: CGFloat = 16) {
    let outer = r.insetBy(dx: -bezel, dy: -bezel)
    shadowed(60, 30, black(0.7)) { fillRound(outer, radius + bezel, rgb(0x0C0C0E)) }
    strokeRound(outer.insetBy(dx: 1, dy: 1), radius + bezel - 1, rgb(0x48484A), 2)
}

// MARK: - Desktop (canonical 1280 × 800)

let resolutions = ["1024 × 665", "1147 × 745", "1312 × 852", "1512 × 982", "1710 × 1112", "1800 × 1169", "2056 × 1329"]
let resolutionWidths: [CGFloat] = [1024, 1147, 1312, 1512, 1710, 1800, 2056]

struct Desktop {
    var wallpaper = wallpaperBlue
    var uiScale: CGFloat = 1          // 1 = 1512 × 982 "looks like"
    var popover: CGFloat = 0          // 0 hidden … 1 open
    var brightness: CGFloat = 0.82
    var resolution: CGFloat = 0.5     // slider position, already stepped
    var committedResolution = "1512 × 982"
    var black: CGFloat = 0            // mode-change fade
    var windows = true
}

/// Points → canonical pixels.
let pointScale: CGFloat = 1.38
let menuSize = CGSize(width: 320, height: 252)

struct DesktopLayout {
    var rect: CGRect           // where the 1280 × 800 desktop lands in the frame
    var desktop: Desktop
    var P: CGFloat { pointScale * desktop.uiScale }
    var logicalWidth: CGFloat { 1280 / P }
    var statusIconX: CGFloat { logicalWidth - 232 }
    var menuOrigin: CGPoint { CGPoint(x: min(statusIconX - 34, logicalWidth - menuSize.width - 8), y: 28) }
    var brightnessRect: CGRect { CGRect(x: 10, y: 50, width: 300, height: 22) }
    var resolutionRect: CGRect { CGRect(x: 10, y: 80, width: 300, height: 22) }

    /// Maps a point in logical desktop points to frame pixels.
    func frame(_ pt: CGPoint) -> CGPoint {
        let k = rect.width / 1280
        return CGPoint(x: rect.minX + pt.x * P * k, y: rect.minY + pt.y * P * k)
    }
    func menuPoint(_ pt: CGPoint) -> CGPoint { frame(CGPoint(x: menuOrigin.x + pt.x, y: menuOrigin.y + pt.y)) }
}

func drawDesktop(_ L: DesktopLayout, bezel: Bool = true) {
    let d = L.desktop
    let k = L.rect.width / 1280
    ctx.saveGState()
    ctx.translateBy(x: L.rect.minX, y: L.rect.minY)
    ctx.scaleBy(x: k, y: k)
    if bezel { screenBezel(CGRect(x: 0, y: 0, width: 1280, height: 800)) }
    ctx.addPath(roundPath(CGRect(x: 0, y: 0, width: 1280, height: 800), 12))
    ctx.clip()
    drawImage(d.wallpaper, in: CGRect(x: 0, y: 0, width: 1280, height: 800))

    ctx.saveGState()
    ctx.scaleBy(x: L.P, y: L.P)
    let lw = L.logicalWidth, lh = 800 / L.P
    if d.windows { drawWindows(logicalWidth: lw, logicalHeight: lh) }
    // Menu bar
    ctx.setFillColor(white(0.16).cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: lw, height: 24))
    symbol("apple.logo", 13, .medium, white(0.95), at: CGPoint(x: 20, y: 12))
    var x: CGFloat = 40
    for (i, item) in ["Finder", "File", "Edit", "View", "Go", "Window", "Help"].enumerated() {
        x += text(item, 13, i == 0 ? .bold : .regular, white(0.95), at: CGPoint(x: x, y: 12), align: .left) + 18
    }
    text("Thu 12 Nov  9:41", 13, .medium, white(0.95), at: CGPoint(x: lw - 14, y: 12), align: .right)
    symbol("wifi", 13, .medium, white(0.95), at: CGPoint(x: lw - 140, y: 12))
    symbol("battery.75percent", 13, .regular, white(0.95), at: CGPoint(x: lw - 176, y: 12))
    symbol("switch.2", 12, .medium, white(0.95), at: CGPoint(x: lw - 206, y: 12))
    if d.popover > 0.01 { fillRound(CGRect(x: L.statusIconX - 15, y: 2, width: 30, height: 20), 5, white(0.22 * d.popover)) }
    symbol("display", 13, .medium, white(0.95), at: CGPoint(x: L.statusIconX, y: 12))

    if d.popover > 0.001 {
        let o = L.menuOrigin
        ctx.saveGState()
        ctx.translateBy(x: o.x, y: o.y)
        let s = lerp(0.96, 1, easeOut(d.popover))
        scaled(s, about: CGPoint(x: L.statusIconX - o.x, y: 0)) {
            withAlpha(d.popover) { drawMenu(d, L) }
        }
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Brightness: everything on the panel dims, including the menu.
    let dim = (1 - d.brightness) * 0.78
    if dim > 0 { ctx.setFillColor(black(dim).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 1280, height: 800)) }
    if d.black > 0 { ctx.setFillColor(black(d.black).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: 1280, height: 800)) }
    ctx.restoreGState()
}

func trafficLights(_ o: CGPoint) {
    for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        fillRound(CGRect(x: o.x + CGFloat(i) * 20, y: o.y, width: 12, height: 12), 6, rgb(UInt32(c)))
    }
}

func drawWindows(logicalWidth lw: CGFloat, logicalHeight lh: CGFloat) {
    // Photos-style window
    let w1 = CGRect(x: 56, y: 70, width: 560, height: 370)
    shadowed(40, 18, black(0.55)) { fillRound(w1, 12, rgb(0x1E1E21, 0.97)) }
    ctx.saveGState()
    ctx.addPath(roundPath(w1, 12)); ctx.clip()
    ctx.setFillColor(rgb(0x2A2A2E, 0.96).cgColor)
    ctx.fill(CGRect(x: w1.minX, y: w1.minY, width: 150, height: w1.height))
    trafficLights(CGPoint(x: w1.minX + 16, y: w1.minY + 16))
    for (i, item) in ["Library", "Memories", "Favourites", "Recents", "Displays"].enumerated() {
        if i == 0 { fillRound(CGRect(x: w1.minX + 8, y: w1.minY + 48, width: 134, height: 22), 6, white(0.1)) }
        text(item, 12, .regular, white(0.8), at: CGPoint(x: w1.minX + 18, y: w1.minY + 59 + CGFloat(i) * 26), align: .left)
    }
    text("Library", 15, .bold, white(0.9), at: CGPoint(x: w1.minX + 168, y: w1.minY + 24), align: .left)
    let tiles: [(UInt32, UInt32)] = [(0x0A84FF, 0x64D2FF), (0xFF375F, 0xFF9F0A), (0x30D158, 0x64D2FF), (0xBF5AF2, 0x5E5CE6),
                                     (0xFF9F0A, 0xFFD60A), (0x5E5CE6, 0x0A84FF), (0x64D2FF, 0x30D158), (0xFF375F, 0xBF5AF2),
                                     (0x0A84FF, 0x5E5CE6), (0xFFD60A, 0xFF375F), (0x30D158, 0x0A84FF), (0xBF5AF2, 0xFF375F)]
    for (i, pair) in tiles.enumerated() {
        let r = CGRect(x: w1.minX + 166 + CGFloat(i % 4) * 96, y: w1.minY + 46 + CGFloat(i / 4) * 104, width: 88, height: 96)
        ctx.saveGState()
        ctx.addPath(roundPath(r, 6)); ctx.clip()
        ctx.drawLinearGradient(gradient([rgb(pair.0), rgb(pair.1)]), start: r.origin,
                               end: CGPoint(x: r.maxX, y: r.maxY), options: [])
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Notes-style window
    let w2 = CGRect(x: lw - 470, y: lh - 420, width: 380, height: 270)
    shadowed(40, 18, black(0.55)) { fillRound(w2, 12, rgb(0x2B2A27, 0.97)) }
    trafficLights(CGPoint(x: w2.minX + 16, y: w2.minY + 16))
    text("Display setup", 18, .bold, white(0.92), at: CGPoint(x: w2.minX + 22, y: w2.minY + 58), align: .left)
    for i in 0..<6 {
        let lineW: CGFloat = [300, 270, 320, 190, 290, 240][i]
        fillRound(CGRect(x: w2.minX + 22, y: w2.minY + 86 + CGFloat(i) * 24, width: lineW, height: 8), 4, white(0.16))
    }

    // Dock
    let count = 9
    let dockW = CGFloat(count) * 50 + 16
    let dock = CGRect(x: (lw - dockW) / 2, y: lh - 66, width: dockW, height: 58)
    fillRound(dock, 18, white(0.16))
    strokeRound(dock, 18, white(0.2), 1)
    let colors: [(UInt32, UInt32)] = [(0x64D2FF, 0x0A84FF), (0xFFFFFF, 0xC7C7CC), (0x30D158, 0x248A3D), (0xFFD60A, 0xFF9F0A),
                                      (0xFF375F, 0xBF5AF2), (0x5E5CE6, 0x0A84FF), (0x3A3A3C, 0x1C1C1E), (0xFF9F0A, 0xFF375F),
                                      (0x8E8E93, 0x48484A)]
    for (i, c) in colors.enumerated() {
        let r = CGRect(x: dock.minX + 11 + CGFloat(i) * 50, y: dock.minY + 7, width: 44, height: 44)
        ctx.saveGState()
        ctx.addPath(roundPath(r, 10)); ctx.clip()
        ctx.drawLinearGradient(gradient([rgb(c.0), rgb(c.1)]), start: CGPoint(x: r.midX, y: r.minY),
                               end: CGPoint(x: r.midX, y: r.maxY), options: [])
        ctx.restoreGState()
    }
}

func drawMenu(_ d: Desktop, _ L: DesktopLayout) {
    menuBackground(menuSize)
    deviceHeader(y: 6, symbolName: "laptopcomputer", name: "Built-in Retina Display",
                 subtitle: "\(d.committedResolution) · 120 Hz", connected: true, badge: "HiDPI")
    let pct = Int((d.brightness * 100).rounded())
    capsuleSlider(L.brightnessRect, value: d.brightness, symbolName: d.brightness < 0.3 ? "sun.min.fill" : "sun.max.fill",
                  trailing: "\(pct)%", markers: [0.3])
    let index = Int((d.resolution * 6).rounded())
    capsuleSlider(L.resolutionRect, value: d.resolution, symbolName: "arrow.up.left.and.arrow.down.right",
                  trailing: resolutions[index], markers: [0.5])
    symbol("chevron.compact.down", 12, .bold, white(0.35), at: CGPoint(x: 160, y: 114))
    divider(y: 126)
    deviceHeader(y: 130, symbolName: "display", name: "LG UltraFine 5K", subtitle: "5120 × 2880 · DDC/CI", connected: true)
    divider(y: 172)
    deviceHeader(y: 176, symbolName: "rectangle.dashed", name: "Virtual Screen",
                 subtitle: "Virtual screen · 5120 × 2160", connected: false)
    divider(y: 218)
    symbol("gearshape", 13, .regular, white(0.7), at: CGPoint(x: 24, y: 236))
    symbol("power", 13, .regular, white(0.7), at: CGPoint(x: 296, y: 236))
}

// MARK: - Scenes

func sceneTitle(_ t: Double) {
    let e = envelope(t, 0.0, 3.3, fin: 0.01, fout: 0.5)
    withAlpha(e) {
        glow(CGPoint(x: 960, y: 1180), 900, rgb(0x0A84FF, 0.22 * easeOut(p(t, 0, 2))))
        let a1 = easeOut(p(t, 0.25, 1.0))
        withAlpha(a1) {
            scaled(lerp(1.05, 1, a1), about: CGPoint(x: 960, y: 470)) {
                text("Every display.", 132, .bold, white(0.97), at: CGPoint(x: 960, y: 470 + (1 - a1) * 24))
            }
        }
        let a2 = easeOut(p(t, 1.05, 1.8))
        withAlpha(a2) {
            scaled(lerp(1.05, 1, a2), about: CGPoint(x: 960, y: 620)) {
                gradientText("One menu bar.", 132, .bold, headlineGradient, center: CGPoint(x: 960, y: 620 + (1 - a2) * 24))
            }
        }
    }
}

func sceneIcon(_ t: Double) {
    let e = envelope(t, 3.2, 6.7, fin: 0.3, fout: 0.55)
    let zoomOut = easeIn(p(t, 6.0, 6.7))
    withAlpha(e) {
        scaled(1 + zoomOut * 0.18, about: CGPoint(x: 960, y: 540)) {
            let a = p(t, 3.3, 4.2)
            glow(CGPoint(x: 960, y: 450), 300 + 160 * easeOut(a), rgb(0x0A84FF, 0.45 * easeOut(a)))
            let s = lerp(0.55, 1, easeOutBack(a))
            withAlpha(easeOut(p(t, 3.3, 3.7))) {
                shadowed(60, 24, black(0.6)) { drawIcon(center: CGPoint(x: 960, y: 450), size: 320 * s) }
            }
            let b = easeOut(p(t, 3.95, 4.7))
            withAlpha(b) {
                text("Great Display", 92, .bold, white(0.97), at: CGPoint(x: 960, y: 700 + (1 - b) * 20))
            }
            let c = easeOut(p(t, 4.4, 5.1))
            withAlpha(c) {
                text("The display manager for your menu bar.", 32, .medium, white(0.55), at: CGPoint(x: 960, y: 775 + (1 - c) * 16))
            }
        }
    }
}

let mainRect = CGRect(x: 320, y: 46, width: 1280, height: 800)
let sideRect = CGRect(x: 110, y: 232, width: 880, height: 550)

func desktopLayout(_ t: Double) -> DesktopLayout {
    var d = Desktop()
    d.popover = easeOut(p(t, 7.5, 7.85)) * (1 - easeIn(p(t, 16.3, 16.55)))
    d.brightness = track(t, [(0, 0.82), (8.65, 0.82), (9.9, 0.2), (10.5, 0.2), (11.55, 0.66)])
    let dragged = track(t, [(0, 3.0 / 6), (13.3, 3.0 / 6), (14.45, 1)])
    d.resolution = (dragged * 6).rounded() / 6
    d.black = t < 14.55 ? 0 : (t < 14.85 ? easeInOut(p(t, 14.55, 14.85)) : 1 - easeInOut(p(t, 14.85, 15.35)))
    if t >= 14.85 {
        d.uiScale = 1512 / 2056
        d.committedResolution = resolutions[6]
    }
    let rect = lerp(mainRect, sideRect, easeInOut(p(t, 17.0, 17.9)))
    return DesktopLayout(rect: rect, desktop: d)
}

func sceneDesktop(_ t: Double) {
    let e = envelope(t, 6.35, 21.45, fin: 0.6, fout: 0.45)
    guard e > 0 else { return }
    let L = desktopLayout(t)
    let entry = easeOut(p(t, 6.35, 7.2))
    withAlpha(e) {
        scaled(lerp(1.08, 1, entry), about: CGPoint(x: 960, y: 446)) {
            drawDesktop(L)
        }
        virtualScreen(t)

        // Cursor
        let icon = L.frame(CGPoint(x: L.statusIconX + 2, y: 13))
        let start = CGPoint(x: 1040, y: 520)
        let bKnob = L.menuPoint(knobCenter(L.brightnessRect, L.desktop.brightness))
        let rKnob = L.menuPoint(knobCenter(L.resolutionRect, L.desktop.resolution))
        var pos = start
        var pressed = false
        switch t {
        case ..<7.9: pos = lerp(start, icon, easeInOut(p(t, 6.9, 7.45))); pressed = (7.42...7.58).contains(t)
        case ..<8.65: pos = lerp(icon, bKnob, easeInOut(p(t, 7.9, 8.55))); pressed = t > 8.55
        case ..<11.6: pos = bKnob; pressed = true
        case ..<13.3: pos = lerp(bKnob, rKnob, easeInOut(p(t, 12.2, 13.15))); pressed = t > 13.2
        case ..<14.5: pos = rKnob; pressed = true
        default:
            let away = L.frame(CGPoint(x: L.logicalWidth * 0.42, y: 300))
            let fromKnob = L.menuPoint(knobCenter(L.resolutionRect, L.desktop.resolution))
            pos = lerp(fromKnob, away, easeInOut(p(t, 15.4, 16.1)))
            pressed = (16.18...16.3).contains(t)
        }
        let cursorAlpha = easeOut(p(t, 6.8, 7.1)) * (1 - p(t, 16.5, 16.8))
        withAlpha(cursorAlpha) { cursor(at: pos, pressed: pressed) }
    }
    caption(t, 8.3, 12.1, "Brightness, all the way down.", "Native, DDC/CI and software dimming in a single slider.")
    caption(t, 12.35, 16.75, "Every resolution. Every refresh rate.", "Pixel-perfect HiDPI modes, one step at a time.")
    caption(t, 17.5, 21.3, "Virtual screens. Any shape.", "Up to 16K, mirrored, streamed or auto-connected.")
}

func virtualScreen(_ t: Double) {
    let appear = easeOutBack(p(t, 17.85, 18.5))
    guard appear > 0 else { return }
    let w = track(t, [(0, 700), (19.0, 700), (19.55, 760), (19.95, 760), (20.5, 780)])
    let h = track(t, [(0, 394), (19.0, 394), (19.55, 326), (19.95, 326), (20.5, 219)])
    let center = CGPoint(x: 1445, y: 507)
    let r = CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
    let presets = [("16:9", "3840 × 2160"), ("21:9", "5120 × 2160"), ("32:9", "7680 × 2160")]
    let active = t < 19.28 ? 0 : (t < 20.22 ? 1 : 2)
    withAlpha(clamp01(appear)) {
        scaled(lerp(0.9, 1, appear), about: center) {
            let fill = easeOut(p(t, 18.3, 18.9))
            withAlpha(fill) {
                shadowed(50, 24, black(0.6)) { fillRound(r, 12, rgb(0x101014)) }
                ctx.saveGState()
                ctx.addPath(roundPath(r, 12)); ctx.clip()
                drawImage(wallpaperTeal, in: CGRect(x: r.midX - 640, y: r.midY - 400, width: 1280, height: 800))
                ctx.restoreGState()
            }
            strokeRound(r, 12, rgb(0x64D2FF, 0.9), 3, dash: [14, 10])
            symbol("rectangle.dashed", 34, .regular, white(0.9), at: CGPoint(x: r.midX, y: r.midY - 40))
            text("Virtual Screen", 30, .semibold, white(0.95), at: CGPoint(x: r.midX, y: r.midY + 10))
            text("\(presets[active].1) · \(presets[active].0)", 20, .medium, white(0.65),
                 at: CGPoint(x: r.midX, y: r.midY + 44), mono: true)
        }
        // Aspect-ratio chips
        let chipY = r.maxY + 34
        for (i, preset) in presets.enumerated() {
            let cr = CGRect(x: center.x - 165 + CGFloat(i) * 115, y: chipY, width: 100, height: 40)
            fillRound(cr, 20, i == active ? accent : white(0.1))
            text(preset.0, 19, .semibold, white(i == active ? 1 : 0.7), at: CGPoint(x: cr.midX, y: cr.midY))
        }
    }
}

// Device control on an external monitor
let monitorRect = CGRect(x: 150, y: 96, width: 1000, height: 562)
let panelOrigin = CGPoint(x: 1236, y: 150)
let panelScale: CGFloat = 1.42
let contrastRect = CGRect(x: 10, y: 74, width: 300, height: 22)
let volumeRect = CGRect(x: 10, y: 104, width: 300, height: 22)

func panelPoint(_ pt: CGPoint) -> CGPoint {
    CGPoint(x: panelOrigin.x + pt.x * panelScale, y: panelOrigin.y + pt.y * panelScale)
}

func sceneDDC(_ t: Double) {
    let e = envelope(t, 21.15, 25.25, fin: 0.55, fout: 0.4)
    guard e > 0 else { return }
    let contrast = track(t, [(0, 0.5), (22.1, 0.5), (22.85, 0.8)])
    let volume = track(t, [(0, 0.3), (23.35, 0.3), (24.35, 0.75)])
    let rise = (1 - easeOut(p(t, 21.15, 21.9))) * 40
    withAlpha(e) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: rise)
        // Monitor
        let m = monitorRect
        let neck = CGRect(x: m.midX - 46, y: m.maxY + 14, width: 92, height: 150)
        ctx.saveGState()
        ctx.addRect(neck); ctx.clip()
        ctx.drawLinearGradient(gradient([rgb(0x8E8E93), rgb(0xD1D1D6), rgb(0x8E8E93)]),
                               start: CGPoint(x: neck.minX, y: 0), end: CGPoint(x: neck.maxX, y: 0), options: [])
        ctx.restoreGState()
        shadowed(20, 8, black(0.6)) { fillRound(CGRect(x: m.midX - 160, y: m.maxY + 160, width: 320, height: 18), 9, rgb(0xAEAEB2)) }
        screenBezel(m, radius: 6, bezel: 14)
        ctx.saveGState()
        ctx.addPath(roundPath(m, 6)); ctx.clip()
        drawImage(wallpaperWarm, in: CGRect(x: m.minX - 140, y: m.minY - 119, width: 1280, height: 800))
        // Contrast: lower values wash the image out towards mid grey.
        ctx.setFillColor(NSColor(srgbRed: 0.45, green: 0.42, blue: 0.45, alpha: (1 - contrast) * 0.7).cgColor)
        ctx.fill(m)
        // OSD
        let showContrast = envelope(t, 22.05, 23.2, fin: 0.2, fout: 0.3)
        let showVolume = envelope(t, 23.3, 25.0, fin: 0.2, fout: 0.4)
        for (alpha, name, value) in [(showContrast, "circle.lefthalf.filled", contrast), (showVolume, "speaker.wave.3.fill", volume)] where alpha > 0 {
            withAlpha(alpha) {
                let osd = CGRect(x: m.midX - 150, y: m.maxY - 130, width: 300, height: 82)
                shadowed(30, 10, black(0.4)) { fillRound(osd, 22, rgb(0x2C2C2E, 0.78)) }
                strokeRound(osd, 22, white(0.22), 1)
                symbol(name, 26, .medium, white(0.95), at: CGPoint(x: osd.minX + 42, y: osd.midY))
                let bar = CGRect(x: osd.minX + 80, y: osd.midY - 5, width: 190, height: 10)
                fillRound(bar, 5, white(0.2))
                fillRound(CGRect(x: bar.minX, y: bar.minY, width: max(10, bar.width * value), height: bar.height), 5, white(0.95))
            }
        }
        ctx.restoreGState()

        // Device control panel
        let panelIn = easeOut(p(t, 21.45, 22.0))
        withAlpha(panelIn) {
            ctx.saveGState()
            ctx.translateBy(x: panelOrigin.x + (1 - panelIn) * 30, y: panelOrigin.y)
            ctx.scaleBy(x: panelScale, y: panelScale)
            menuBackground(CGSize(width: 320, height: 300))
            deviceHeader(y: 6, symbolName: "display", name: "LG UltraFine 5K", subtitle: "MCCS 2.2 · 34 VCP codes", connected: true)
            symbol("slider.horizontal.2.square", 12, .medium, white(0.8), at: CGPoint(x: 22, y: 58))
            text("Device Control", 13, .semibold, white(0.9), at: CGPoint(x: 38, y: 58), align: .left)
            capsuleSlider(contrastRect, value: contrast, symbolName: "circle.lefthalf.filled", trailing: "Contrast \(Int(contrast * 100))")
            capsuleSlider(volumeRect, value: volume, symbolName: "speaker.wave.2.fill", trailing: "Volume \(Int(volume * 100))")
            text("INPUT SOURCE", 9.5, .semibold, white(0.4), at: CGPoint(x: 16, y: 144), align: .left)
            for (i, item) in [("DisplayPort 1", "cable.connector", true), ("HDMI 1", "cable.connector.horizontal", false),
                              ("USB-C", "cable.connector", false)].enumerated() {
                let y = 164 + CGFloat(i) * 24
                if item.2 { fillRound(CGRect(x: 6, y: y - 11, width: 308, height: 22), 5, white(0.08)) }
                if item.2 { symbol("checkmark", 10, .bold, white(0.9), at: CGPoint(x: 18, y: y)) }
                symbol(item.1, 11, .regular, white(0.7), at: CGPoint(x: 36, y: y))
                text(item.0, 13, .regular, white(0.9), at: CGPoint(x: 50, y: y), align: .left)
            }
            divider(y: 238)
            symbol("camera.filters", 12, .medium, white(0.7), at: CGPoint(x: 22, y: 258))
            text("Picture Mode", 13, .regular, white(0.9), at: CGPoint(x: 38, y: 258), align: .left)
            text("Standard", 12, .regular, white(0.5), at: CGPoint(x: 300, y: 258), align: .right)
            symbol("powersleep", 12, .medium, white(0.7), at: CGPoint(x: 22, y: 282))
            text("Put Display in Standby", 13, .regular, white(0.9), at: CGPoint(x: 38, y: 282), align: .left)
            ctx.restoreGState()
        }

        // Cursor
        let cKnob = panelPoint(knobCenter(contrastRect, contrast))
        let vKnob = panelPoint(knobCenter(volumeRect, volume))
        let start = CGPoint(x: 1180, y: 620)
        var pos = start
        var pressed = false
        switch t {
        case ..<22.1: pos = lerp(start, cKnob, easeInOut(p(t, 21.6, 22.05))); pressed = t > 22.05
        case ..<22.9: pos = cKnob; pressed = true
        case ..<23.35: pos = lerp(cKnob, vKnob, easeInOut(p(t, 22.95, 23.3))); pressed = t > 23.3
        case ..<24.4: pos = vKnob; pressed = true
        default: pos = lerp(vKnob, CGPoint(x: vKnob.x + 60, y: vKnob.y + 120), easeInOut(p(t, 24.4, 25.0)))
        }
        withAlpha(easeOut(p(t, 21.5, 21.8))) { cursor(at: pos, pressed: pressed) }
        ctx.restoreGState()
    }
    caption(t, 21.6, 25.1, "Your monitor's controls, on your Mac.", "Contrast, volume, input source and picture modes over DDC/CI.")
}

func sceneMontage(_ t: Double) {
    let words = ["Mirroring.", "Streaming.", "Rotation.", "HDR.", "Night Shift."]
    let slot = 0.46, start = 25.15
    for (i, word) in words.enumerated() {
        let a = start + Double(i) * slot
        let e = envelope(t, a, a + slot, fin: 0.12, fout: 0.1)
        guard e > 0 else { continue }
        let s = lerp(1.08, 1, easeOut(p(t, a, a + slot)))
        withAlpha(e) {
            scaled(s, about: CGPoint(x: 960, y: 530)) {
                if i == words.count - 1 {
                    gradientText(word, 170, .bold, [rgb(0xFF9F0A), rgb(0xFF375F), rgb(0xBF5AF2)], center: CGPoint(x: 960, y: 530))
                } else {
                    text(word, 170, .bold, white(0.97), at: CGPoint(x: 960, y: 530))
                }
            }
        }
    }
}

func sceneEnd(_ t: Double) {
    let e = envelope(t, 27.45, 31.0, fin: 0.3, fout: 0.6)
    withAlpha(e) {
        let a = p(t, 27.5, 28.3)
        glow(CGPoint(x: 960, y: 380), 420, rgb(0x0A84FF, 0.4 * easeOut(a)))
        withAlpha(easeOut(p(t, 27.5, 27.8))) {
            shadowed(50, 20, black(0.6)) { drawIcon(center: CGPoint(x: 960, y: 380), size: 240 * lerp(0.6, 1, easeOutBack(a))) }
        }
        let b = easeOut(p(t, 27.95, 28.6))
        withAlpha(b) { text("Great Display", 104, .bold, white(0.97), at: CGPoint(x: 960, y: 570 + (1 - b) * 18)) }
        let c = easeOut(p(t, 28.3, 28.9))
        withAlpha(c) { text("Free and open source. For macOS 14 and later.", 34, .medium, white(0.6), at: CGPoint(x: 960, y: 672 + (1 - c) * 14)) }
        let d = easeOut(p(t, 28.65, 29.25))
        withAlpha(d) {
            let pill = CGRect(x: 960 - 190, y: 744 + (1 - d) * 12, width: 380, height: 70)
            fillRound(pill, 35, accent)
            text("Download on GitHub", 28, .semibold, white(1), at: CGPoint(x: 960, y: pill.midY))
        }
    }
}

// MARK: - Frame

func drawFrame(_ c: CGContext, t: Double) {
    ctx = c
    c.translateBy(x: 0, y: CGFloat(H))
    c.scaleBy(x: 1, y: -1)
    c.setShouldAntialias(true)
    c.setAllowsFontSmoothing(true)
    c.interpolationQuality = .high
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: true)
    c.setFillColor(black(1).cgColor)
    c.fill(CGRect(x: 0, y: 0, width: W, height: H))
    if t < 3.4 { sceneTitle(t) }
    if t > 3.1 && t < 6.8 { sceneIcon(t) }
    if t > 6.3 && t < 21.5 { sceneDesktop(t) }
    if t > 21.1 && t < 25.3 { sceneDDC(t) }
    if t > 25.1 && t < 27.6 { sceneMontage(t) }
    if t > 27.4 { sceneEnd(t) }
    NSGraphicsContext.restoreGraphicsState()
}

func bitmapContext() -> CGContext {
    CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
}

func writeImage(t: Double, to url: URL, jpeg: Bool) {
    let c = bitmapContext()
    drawFrame(c, t: t)
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    let data = jpeg ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82])!
                    : rep.representation(using: .png, properties: [:])!
    try! data.write(to: url)
}

func renderVideo(to url: URL) throws {
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: W,
        AVVideoHeightKey: H,
        AVVideoColorPropertiesKey: [
            AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
            AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
            AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 3_800_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60,
            AVVideoExpectedSourceFrameRateKey: FPS,
        ],
    ])
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: W,
        kCVPixelBufferHeightKey as String: H,
    ])
    writer.add(input)
    writer.shouldOptimizeForNetworkUse = true
    guard writer.startWriting() else { throw writer.error! }
    writer.startSession(atSourceTime: .zero)
    let frames = Int(DURATION * Double(FPS))
    for i in 0..<frames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        guard let pb = buffer else { fatalError("no pixel buffer") }
        CVPixelBufferLockBaseAddress(pb, [])
        let c = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
                          bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: srgb,
                          bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        autoreleasepool { drawFrame(c, t: Double(i) / Double(FPS)) }
        CVPixelBufferUnlockBaseAddress(pb, [])
        adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: FPS))
        if i % 150 == 0 { print("frame \(i)/\(frames)") }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    if writer.status != .completed { throw writer.error ?? NSError(domain: "promo", code: 1) }
}

// MARK: - Main

var args = Array(CommandLine.arguments.dropFirst())
if args.first == "--stills", args.count == 3 {
    let dir = URL(fileURLWithPath: args[1])
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    for value in args[2].split(separator: ",") {
        let t = Double(value)!
        writeImage(t: t, to: dir.appendingPathComponent(String(format: "frame-%05.2f.png", t)), jpeg: false)
    }
    exit(0)
}
guard let output = args.first else {
    print("usage: make_promo_video <out.mp4> [--poster <poster.jpg> <seconds>] | --stills <dir> <t1,t2,…>")
    exit(64)
}
if let i = args.firstIndex(of: "--poster"), args.count > i + 2 {
    writeImage(t: Double(args[i + 2])!, to: URL(fileURLWithPath: args[i + 1]), jpeg: true)
    print("wrote \(args[i + 1])")
}
try renderVideo(to: URL(fileURLWithPath: output))
print("wrote \(output)")
