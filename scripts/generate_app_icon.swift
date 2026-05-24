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

    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.13, alpha: 1).setFill()
    roundedRect(bounds.insetBy(dx: 60 * scale, dy: 60 * scale), radius: 210 * scale).fill()

    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.22, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.13, alpha: 1)
    ])
    background?.draw(in: roundedRect(bounds.insetBy(dx: 76 * scale, dy: 76 * scale), radius: 188 * scale), angle: -45)

    let backRect = CGRect(x: 245 * scale, y: 455 * scale, width: 430 * scale, height: 285 * scale)
    NSColor(calibratedRed: 0.27, green: 0.31, blue: 0.37, alpha: 1).setFill()
    roundedRect(backRect, radius: 46 * scale).fill()

    let frontRect = CGRect(x: 350 * scale, y: 285 * scale, width: 430 * scale, height: 285 * scale)
    NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1).setFill()
    roundedRect(frontRect, radius: 46 * scale).fill()

    NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.18, alpha: 1).setFill()
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 250 * scale, y: 310 * scale))
    arrow.line(to: CGPoint(x: 250 * scale, y: 215 * scale))
    arrow.line(to: CGPoint(x: 125 * scale, y: 350 * scale))
    arrow.line(to: CGPoint(x: 250 * scale, y: 485 * scale))
    arrow.line(to: CGPoint(x: 250 * scale, y: 390 * scale))
    arrow.line(to: CGPoint(x: 490 * scale, y: 390 * scale))
    arrow.line(to: CGPoint(x: 490 * scale, y: 310 * scale))
    arrow.close()
    arrow.fill()

    NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.18, alpha: 1).setFill()
    roundedRect(CGRect(x: 420 * scale, y: 470 * scale, width: 130 * scale, height: 34 * scale), radius: 17 * scale).fill()
    roundedRect(CGRect(x: 420 * scale, y: 395 * scale, width: 240 * scale, height: 34 * scale), radius: 17 * scale).fill()

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
