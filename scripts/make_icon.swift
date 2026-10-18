import AppKit

func sectorPath(center: CGPoint, a0: Double, a1: Double, r1: Double, r2: Double, c: Double) -> NSBezierPath {
    let ro = r2 - c, ri = r1 + c
    let dO = asin(c / ro), dI = asin(c / ri)
    let lineO = (ro * ro - c * c).squareRoot()
    let lineI = (ri * ri - c * c).squareRoot()
    let half = Double.pi / 2
    var pts: [CGPoint] = []

    func arc(_ centerR: Double, _ centerA: Double, _ r: Double, _ from: Double, _ to: Double) {
        let cx = centerR * cos(centerA), cy = centerR * sin(centerA)
        let steps = max(2, Int(abs(to - from) * r / 1.5))
        for i in 0...steps {
            let t = from + (to - from) * Double(i) / Double(steps)
            pts.append(CGPoint(x: center.x + CGFloat(cx + r * cos(t)),
                               y: center.y + CGFloat(cy + r * sin(t))))
        }
    }

    arc(0, 0, r2, a0 + dO, a1 - dO)
    arc(ro, a1 - dO, c, a1 - dO, a1 + half)
    pts.append(CGPoint(x: center.x + CGFloat(lineI * cos(a1)), y: center.y + CGFloat(lineI * sin(a1))))
    arc(ri, a1 - dI, c, a1 + half, a1 - dI + Double.pi)
    arc(0, 0, r1, a1 - dI, a0 + dI)
    arc(ri, a0 + dI, c, a0 + dI + Double.pi, a0 + 3 * half)
    pts.append(CGPoint(x: center.x + CGFloat(lineO * cos(a0)), y: center.y + CGFloat(lineO * sin(a0))))
    arc(ro, a0 + dO, c, a0 + 3 * half, a0 + dO + 2 * Double.pi)

    let path = NSBezierPath()
    path.move(to: pts[0])
    for p in pts.dropFirst() { path.line(to: p) }
    path.close()
    return path
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(size) / 1024)
    scale.concat()

    let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                          xRadius: 185, yRadius: 185)
    let top = NSColor(srgbRed: 1.0, green: 0.71, blue: 0.37, alpha: 1)
    let bottom = NSColor(srgbRed: 1.0, green: 0.42, blue: 0.17, alpha: 1)
    NSGradient(starting: top, ending: bottom)!.draw(in: bg, angle: -90)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 22
    shadow.set()
    NSColor.white.setFill()

    let center = CGPoint(x: 512, y: 512)
    let n = 6
    let span = 2 * Double.pi / Double(n)
    let gap = 0.09
    for k in 0..<n {
        let mid = Double.pi / 2 + Double(k) * span
        sectorPath(center: center, a0: mid - span / 2 + gap / 2, a1: mid + span / 2 - gap / 2,
                   r1: 150, r2: 330, c: 34).fill()
    }
    NSBezierPath(ovalIn: NSRect(x: 512 - 118, y: 512 - 118, width: 236, height: 236)).fill()
    NSGraphicsContext.restoreGraphicsState()

    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: 512, y: 446))
    arrow.line(to: CGPoint(x: 454, y: 506))
    arrow.line(to: CGPoint(x: 488, y: 506))
    arrow.line(to: CGPoint(x: 488, y: 580))
    arrow.line(to: CGPoint(x: 536, y: 580))
    arrow.line(to: CGPoint(x: 536, y: 506))
    arrow.line(to: CGPoint(x: 570, y: 506))
    arrow.close()
    NSColor(srgbRed: 1.0, green: 0.48, blue: 0.2, alpha: 1).set()
    arrow.lineJoinStyle = .round
    arrow.lineWidth = 14
    arrow.fill()
    arrow.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let files: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
var cache: [Int: Data] = [:]
for (name, size) in files {
    let data = cache[size] ?? render(size: size)
    cache[size] = data
    try? data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(name + ".png"))
}
