// Draws Resources/AppIcon.icns. Run from the repository root:
//
//     swift scripts/make-icon.swift
import AppKit

func draw(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 1024
    ctx.scaleBy(x: s, y: s)

    // macOS icon grid: 824 pt body centred on a 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(bodyPath)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(srgbRed: 0.10, green: 0.11, blue: 0.20, alpha: 1).cgColor,
        NSColor(srgbRed: 0.20, green: 0.17, blue: 0.38, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])

    // The lid, leaning back from the hinge: a trapezoid narrowing upwards.
    let hingeY: CGFloat = 300
    let lid = CGMutablePath()
    lid.move(to: CGPoint(x: 230, y: hingeY))
    lid.addLine(to: CGPoint(x: 794, y: hingeY))
    lid.addLine(to: CGPoint(x: 700, y: 760))
    lid.addLine(to: CGPoint(x: 324, y: 760))
    lid.closeSubpath()
    ctx.saveGState()
    ctx.addPath(lid)
    ctx.clip()
    // Sharp at the hinge, fading and darkening towards the far edge.
    let glass = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(srgbRed: 0.55, green: 0.80, blue: 1.00, alpha: 1).cgColor,
        NSColor(srgbRed: 0.52, green: 0.47, blue: 0.98, alpha: 0.75).cgColor,
        NSColor(srgbRed: 0.30, green: 0.22, blue: 0.60, alpha: 0.15).cgColor,
    ] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(glass, start: CGPoint(x: 512, y: hingeY), end: CGPoint(x: 512, y: 760), options: [])
    // Rows of "content", blurred more the further they are from the hinge.
    for row in 0..<5 {
        let t = CGFloat(row) / 5
        let y = hingeY + 50 + t * 360
        let inset = 40 + t * 94 * 0.9
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 2 + t * 26, color: NSColor.white.withAlphaComponent(0.9 - t * 0.6).cgColor)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.85 - t * 0.65).cgColor)
        let rect = CGRect(x: 230 + inset + 40, y: y, width: 564 - 2 * inset - 80 - (row % 2 == 0 ? 0 : 90), height: 26 - t * 6)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // The upright lid outline the picture leans away from.
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.setLineWidth(6)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 230, y: hingeY, width: 564, height: 470), cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.strokePath()

    // The base.
    let base = CGMutablePath()
    base.addRoundedRect(in: CGRect(x: 170, y: 250, width: 684, height: 46), cornerWidth: 23, cornerHeight: 23)
    let metal = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        NSColor(white: 0.92, alpha: 1).cgColor,
        NSColor(white: 0.62, alpha: 1).cgColor,
    ] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(base)
    ctx.clip()
    ctx.drawLinearGradient(metal, start: CGPoint(x: 512, y: 296), end: CGPoint(x: 512, y: 250), options: [])
    ctx.restoreGState()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let data = draw(size: CGFloat(points * scale)).representation(using: .png, properties: [:])!
        try! data.write(to: iconset.appendingPathComponent(name))
    }
}
try! draw(size: 1024).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: "assets/icon.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "wrote Resources/AppIcon.icns" : "iconutil failed")
