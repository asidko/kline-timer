import AppKit

// Renders the Kline Timer app icon: a blue→purple→pink→orange gradient squircle
// with the white candlestick glyph (the app's brand mark, see CandleGlyph.swift)
// centered. Writes a 1024px PNG to argv[1]. Driven by tools/make-icon.sh, which
// packs it into AppIcon.icns.

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
) else { fatalError("could not allocate bitmap") }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

// Floating squircle, inset to leave room for the drop shadow.
let margin = size * 0.085
let rect = CGRect(x: margin, y: margin, width: size - 2 * margin, height: size - 2 * margin)
let radius = rect.width * 0.2237
let squircle = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

// Drop shadow under the squircle.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.02), blur: size * 0.05,
              color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.white.setFill()
squircle.fill()
ctx.restoreGState()

// Gradient fill (blue → purple → pink → orange), top-left to bottom-right.
ctx.saveGState()
squircle.addClip()
let palette = NSGradient(colors: [rgb(79, 127, 208), rgb(122, 111, 196), rgb(194, 102, 166), rgb(232, 138, 90)])!
palette.draw(in: rect, angle: -45)
ctx.restoreGState()

// Centered white candlestick: full-height wick behind a rounded body.
let cx = size / 2
let bodyW = rect.width * 0.26
let bodyH = rect.height * 0.36
let bodyR = bodyW * 0.22
let bodyRect = CGRect(x: cx - bodyW / 2, y: size / 2 - bodyH / 2, width: bodyW, height: bodyH)
let wickInset = rect.height * 0.16
let wickTop = rect.maxY - wickInset
let wickBot = rect.minY + wickInset

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.006), blur: size * 0.02,
              color: NSColor.black.withAlphaComponent(0.22).cgColor)
NSColor.white.setStroke()
NSColor.white.setFill()
let wick = NSBezierPath()
wick.lineWidth = rect.width * 0.055
wick.lineCapStyle = .round
wick.move(to: CGPoint(x: cx, y: wickBot))
wick.line(to: CGPoint(x: cx, y: wickTop))
wick.stroke()
NSBezierPath(roundedRect: bodyRect, xRadius: bodyR, yRadius: bodyR).fill()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
