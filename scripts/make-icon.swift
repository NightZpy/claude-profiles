// Builds the app icon from the Claude Desktop icon installed on this Mac, with a
// "profiles" badge on top. No Claude artwork is stored in this repo.
// Usage: swift scripts/make-icon.swift <Claude.icns> <out.iconset>
import AppKit

let source = NSImage(contentsOfFile: CommandLine.arguments[1])!
let out = URL(fileURLWithPath: CommandLine.arguments[2])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    source.draw(in: NSRect(x: 0, y: 0, width: s, height: s))

    // Badge in the bottom-right corner, inside the icon's 824/1024 body.
    let d = s * 0.34
    let badge = NSRect(x: s * 0.905 - d, y: s * 0.095, width: d, height: d)
    let shadow = NSShadow()
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.008)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: badge).fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(srgbRed: 0.16, green: 0.17, blue: 0.22, alpha: 1).setFill()
    NSBezierPath(ovalIn: badge.insetBy(dx: d * 0.07, dy: d * 0.07)).fill()

    let config = NSImage.SymbolConfiguration(pointSize: d * 0.42, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "person.2.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let r = NSRect(x: badge.midX - sym.size.width / 2, y: badge.midY - sym.size.height / 2,
                       width: sym.size.width, height: sym.size.height)
        sym.draw(in: r)
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
