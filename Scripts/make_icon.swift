// Renders the Great Display app icon as an .iconset-ready PNG set.
// Usage: swift Scripts/make_icon.swift <output-iconset-directory>

import AppKit
import Foundation

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

func render(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let corner = size * 0.225
    let path = CGPath(roundedRect: rect.insetBy(dx: size * 0.045, dy: size * 0.045),
                      cornerWidth: corner, cornerHeight: corner, transform: nil)
    context.addPath(path)
    context.clip()

    let colors = [
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.20, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.12, alpha: 1).cgColor,
    ] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: size),
                                   end: CGPoint(x: size, y: 0),
                                   options: [])
    }

    // Glow behind the main display.
    context.saveGState()
    let glowRect = CGRect(x: size * 0.16, y: size * 0.24, width: size * 0.60, height: size * 0.46)
    let glowPath = CGPath(roundedRect: glowRect, cornerWidth: size * 0.06, cornerHeight: size * 0.06, transform: nil)
    context.addPath(glowPath)
    context.setShadow(offset: .zero, blur: size * 0.10,
                      color: NSColor(calibratedRed: 0.36, green: 0.66, blue: 1.0, alpha: 0.9).cgColor)
    context.setFillColor(NSColor(calibratedRed: 0.13, green: 0.20, blue: 0.33, alpha: 1).cgColor)
    context.fillPath()
    context.restoreGState()

    // Stand.
    context.setFillColor(NSColor(calibratedWhite: 0.86, alpha: 1).cgColor)
    let stand = CGRect(x: size * 0.41, y: size * 0.16, width: size * 0.18, height: size * 0.035)
    context.addPath(CGPath(roundedRect: stand, cornerWidth: size * 0.017, cornerHeight: size * 0.017, transform: nil))
    context.fillPath()
    let neck = CGRect(x: size * 0.47, y: size * 0.19, width: size * 0.06, height: size * 0.06)
    context.addPath(CGPath(roundedRect: neck, cornerWidth: size * 0.02, cornerHeight: size * 0.02, transform: nil))
    context.fillPath()

    // Screen.
    let screen = CGRect(x: size * 0.18, y: size * 0.28, width: size * 0.56, height: size * 0.42)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: size * 0.045, cornerHeight: size * 0.045, transform: nil)
    context.addPath(screenPath)
    context.setFillColor(NSColor(calibratedRed: 0.08, green: 0.11, blue: 0.18, alpha: 1).cgColor)
    context.fillPath()
    context.addPath(screenPath)
    context.setStrokeColor(NSColor(calibratedWhite: 0.95, alpha: 1).cgColor)
    context.setLineWidth(size * 0.018)
    context.strokePath()

    // Screen content: a rising brightness ramp.
    context.saveGState()
    context.addPath(screenPath)
    context.clip()
    for index in 0..<4 {
        let barHeight = size * (0.06 + 0.055 * CGFloat(index))
        let barWidth = size * 0.055
        let barRect = CGRect(x: screen.minX + size * 0.075 + CGFloat(index) * size * 0.105,
                             y: screen.minY + size * 0.05,
                             width: barWidth,
                             height: barHeight)
        context.addPath(CGPath(roundedRect: barRect, cornerWidth: barWidth / 2, cornerHeight: barWidth / 2, transform: nil))
        let alpha = 0.45 + 0.16 * CGFloat(index)
        context.setFillColor(NSColor(calibratedRed: 0.40, green: 0.75, blue: 1.0, alpha: alpha).cgColor)
        context.fillPath()
    }
    context.restoreGState()

    // Sun marker in the upper-right of the screen.
    let sunCenter = CGPoint(x: screen.maxX - size * 0.09, y: screen.maxY - size * 0.10)
    context.setFillColor(NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.39, alpha: 1).cgColor)
    context.fillEllipse(in: CGRect(x: sunCenter.x - size * 0.028, y: sunCenter.y - size * 0.028,
                                   width: size * 0.056, height: size * 0.056))

    // Secondary display offset behind.
    let secondary = CGRect(x: size * 0.62, y: size * 0.52, width: size * 0.24, height: size * 0.20)
    context.addPath(CGPath(roundedRect: secondary, cornerWidth: size * 0.025, cornerHeight: size * 0.025, transform: nil))
    context.setFillColor(NSColor(calibratedRed: 0.18, green: 0.30, blue: 0.48, alpha: 0.95).cgColor)
    context.fillPath()
    context.addPath(CGPath(roundedRect: secondary, cornerWidth: size * 0.025, cornerHeight: size * 0.025, transform: nil))
    context.setStrokeColor(NSColor(calibratedWhite: 0.85, alpha: 0.8).cgColor)
    context.setLineWidth(size * 0.012)
    context.strokePath()

    image.unlockFocus()
    return image
}

func writePNG(size: CGFloat, name: String) {
    let image = render(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "\(outputDirectory)/\(name)"))
}

let variants: [(CGFloat, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (size, name) in variants {
    writePNG(size: size, name: name)
}
print("Rendered \(variants.count) icon variants into \(outputDirectory)")
