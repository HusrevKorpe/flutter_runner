// Draws the app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make_icon.swift
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: 824pt body centred in 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x000000, 0.3)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x0A7CFF).setFill()
    shape.fill()
    ctx.restoreGState()

    NSGradient(colors: [color(0x22C3FF), color(0x0A7CFF), color(0x3B4BFF)])!
        .draw(in: shape, angle: -60)

    // Soft glossy highlight on the top half.
    ctx.saveGState()
    shape.addClip()
    NSGradient(colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)])!
        .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: -90)
    ctx.restoreGState()

    // Rounded play triangle.
    let play = NSBezierPath()
    let a = NSPoint(x: 400, y: 300), b = NSPoint(x: 400, y: 724), c = NSPoint(x: 735, y: 512)
    play.move(to: NSPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
    play.appendArc(from: b, to: c, radius: 60)
    play.appendArc(from: c, to: a, radius: 60)
    play.appendArc(from: a, to: b, radius: 60)
    play.close()
    ctx.saveGState()
    let glow = NSShadow()
    glow.shadowColor = color(0x001A66, 0.35)
    glow.shadowBlurRadius = 30
    glow.shadowOffset = NSSize(width: 0, height: -12)
    glow.set()
    color(0xFFFFFF).setFill()
    play.fill()
    ctx.restoreGState()

    // Amber bolt badge (hot reload).
    let badge = NSRect(x: 640, y: 170, width: 220, height: 220)
    ctx.saveGState()
    let badgeShadow = NSShadow()
    badgeShadow.shadowColor = color(0x000000, 0.25)
    badgeShadow.shadowBlurRadius = 16
    badgeShadow.shadowOffset = NSSize(width: 0, height: -6)
    badgeShadow.set()
    NSGradient(colors: [color(0xFFD04A), color(0xFF9F1A)])!
        .draw(in: NSBezierPath(ovalIn: badge), angle: -90)
    ctx.restoreGState()
    color(0xFFFFFF).setStroke()
    let ring = NSBezierPath(ovalIn: badge.insetBy(dx: 4, dy: 4))
    ring.lineWidth = 8
    ring.stroke()

    let bolt = NSBezierPath()
    let ox = badge.minX, oy = badge.minY
    for (i, p) in [(122, 196), (66, 104), (106, 104), (92, 28), (156, 122), (114, 122), (128, 196)].enumerated() {
        let pt = NSPoint(x: ox + CGFloat(p.0), y: oy + CGFloat(p.1))
        i == 0 ? bolt.move(to: pt) : bolt.line(to: pt)
    }
    bolt.close()
    bolt.lineJoinStyle = .round
    bolt.lineWidth = 6
    color(0xFFFFFF).setFill()
    color(0xFFFFFF).setStroke()
    bolt.fill()
    bolt.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
