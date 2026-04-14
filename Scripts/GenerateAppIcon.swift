import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Yapa/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let iconSizes: [(name: String, size: CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let colors = [
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.25, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.18, green: 0.21, blue: 0.47, alpha: 1.0).cgColor,
        NSColor(calibratedRed: 0.35, green: 0.20, blue: 0.62, alpha: 1.0).cgColor
    ] as CFArray

    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.58, 1])!
    let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.06, dy: size * 0.06), xRadius: size * 0.22, yRadius: size * 0.22)

    context.saveGState()
    backgroundPath.addClip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size, y: size),
        options: []
    )
    context.restoreGState()

    context.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.04, color: NSColor.black.withAlphaComponent(0.25).cgColor)

    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.48, weight: .semibold, scale: .large)
    if let symbol = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
        let symbolRect = CGRect(x: size * 0.20, y: size * 0.20, width: size * 0.60, height: size * 0.60)
        NSColor.white.withAlphaComponent(0.96).setFill()
        symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }
    try png.write(to: url)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

for entry in iconSizes {
    let image = drawIcon(size: entry.size)
    try writePNG(image, to: outputDirectory.appendingPathComponent(entry.name))
}

print("Generated icon set in \(outputDirectory.path)")
