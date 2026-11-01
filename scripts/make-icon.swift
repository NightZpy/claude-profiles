// Draws the app icon (an asterisk on the front card of a stack of profiles) into an .iconset.
// Usage: swift scripts/make-icon.swift <out.iconset>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

func roundedRect(_ ctx: CGContext, _ r: CGRect, _ radius: CGFloat, _ color: CGColor, shadow: Bool = false) {
    ctx.saveGState()
    if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 26, color: rgb(0, 0.3)) }
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

func draw(_ px: Int) -> Data {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)

    // Squircle on Apple's 1024 grid (824 body, 100 inset).
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0, 0.3))
    ctx.addPath(body); ctx.setFillColor(rgb(0x15171F)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(body); ctx.clip()
    let bg = CGGradient(colorsSpace: nil, colors: [rgb(0x2A2D3E), rgb(0x15171F)] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()

    // Stack of profile cards, back to front.
    roundedRect(ctx, CGRect(x: 300, y: 380, width: 470, height: 440), 70, rgb(0xFFF1E3, 0.18), shadow: true)
    roundedRect(ctx, CGRect(x: 270, y: 300, width: 470, height: 440), 70, rgb(0xFFF1E3, 0.35), shadow: true)
    roundedRect(ctx, CGRect(x: 240, y: 200, width: 470, height: 440), 70, rgb(0x232636), shadow: true)

    // Eight-ray asterisk on the front card, half warm and half cream.
    ctx.saveGState()
    ctx.translateBy(x: 475, y: 420)
    for i in 0..<8 {
        ctx.saveGState()
        ctx.rotate(by: CGFloat(i) * .pi / 4)
        roundedRect(ctx, CGRect(x: -23, y: 24, width: 46, height: 150), 23,
                    rgb(i < 4 ? 0xF5A25D : 0xFFF1E3))
        ctx.restoreGState()
    }
    ctx.setFillColor(rgb(0x232636))
    ctx.fillEllipse(in: CGRect(x: -28.5, y: -28.5, width: 57, height: 57))
    ctx.restoreGState()

    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
