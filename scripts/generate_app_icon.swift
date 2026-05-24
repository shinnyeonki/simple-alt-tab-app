import AppKit

let outputDir = URL(fileURLWithPath: "simple-alt-tab-app/Assets.xcassets/AppIcon.appiconset")
let sizes: [(String, CGFloat)] = [
    ("AppIcon-16.png", 16),
    ("AppIcon-32.png", 32),
    ("AppIcon-64.png", 64),
    ("AppIcon-128.png", 128),
    ("AppIcon-256.png", 256),
    ("AppIcon-512.png", 512),
    ("AppIcon-1024.png", 1024)
]

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(size)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)

    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = size / 1024.0

    NSColor.white.setFill()
    roundedRect(bounds.insetBy(dx: 72 * scale, dy: 72 * scale), radius: 190 * scale).fill()

    NSColor.black.setStroke()
    let outer = roundedRect(bounds.insetBy(dx: 86 * scale, dy: 86 * scale), radius: 176 * scale)
    outer.lineWidth = 28 * scale
    outer.stroke()

    func drawWindow(_ rect: CGRect, active: Bool) {
        let path = roundedRect(rect, radius: 46 * scale)
        path.lineWidth = 28 * scale

        if active {
            NSColor.black.setFill()
            path.fill()
            NSColor.white.setStroke()
            path.stroke()

            NSColor.white.setFill()
            roundedRect(CGRect(
                x: rect.minX + 70 * scale,
                y: rect.maxY - 92 * scale,
                width: 36 * scale,
                height: 36 * scale
            ), radius: 18 * scale).fill()
            roundedRect(CGRect(
                x: rect.minX + 124 * scale,
                y: rect.maxY - 92 * scale,
                width: 36 * scale,
                height: 36 * scale
            ), radius: 18 * scale).fill()
            roundedRect(CGRect(
                x: rect.minX + 178 * scale,
                y: rect.maxY - 92 * scale,
                width: 36 * scale,
                height: 36 * scale
            ), radius: 18 * scale).fill()
        } else {
            NSColor.white.setFill()
            path.fill()
            NSColor.black.setStroke()
            path.stroke()
        }
    }

    drawWindow(CGRect(x: 210 * scale, y: 495 * scale, width: 420 * scale, height: 270 * scale), active: false)
    drawWindow(CGRect(x: 285 * scale, y: 390 * scale, width: 420 * scale, height: 270 * scale), active: false)
    drawWindow(CGRect(x: 360 * scale, y: 275 * scale, width: 420 * scale, height: 270 * scale), active: true)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
for (filename, size) in sizes {
    try writePNG(drawIcon(size: size), to: outputDir.appendingPathComponent(filename))
}
