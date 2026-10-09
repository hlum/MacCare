// Draws the MacCare app icon: graphite rounded square, tick dial, orange core. Run: swift Tools/make-icon.swift <out.png>
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S), flipped: true) { _ in
    let ctx = NSGraphicsContext.current!.cgContext
    // macOS icon template: ~824pt rounded square centred on a 1024 canvas.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let path = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Soft ground shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.addPath(path); ctx.setFillColor(NSColor(red: 0.05, green: 0.05, blue: 0.047, alpha: 1).cgColor); ctx.fillPath()
    ctx.restoreGState()

    // Graphite plate
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [NSColor(red: 0.125, green: 0.122, blue: 0.113, alpha: 1).cgColor,
                                NSColor(red: 0.051, green: 0.051, blue: 0.047, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    // Warm glow behind the core
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [NSColor(red: 1, green: 0.37, blue: 0.12, alpha: 0.32).cgColor,
                                   NSColor(red: 1, green: 0.37, blue: 0.12, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 512, y: 512), startRadius: 0, endCenter: CGPoint(x: 512, y: 512), endRadius: 330, options: [])
    ctx.restoreGState()

    // Hairline edge + top highlight
    ctx.addPath(path); ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.10).cgColor); ctx.setLineWidth(3); ctx.strokePath()

    // Tick dial: 270° sweep, same geometry as the app's health dial
    let n = 49, lit = Int((Double(n - 1) * 0.84).rounded())
    let r: CGFloat = 318
    for i in 0..<n {
        let a = (-225.0 + Double(i) * 270.0 / Double(n - 1)) * .pi / 180
        let head = i == lit, on = i <= lit
        let len: CGFloat = head ? 96 : 66
        var col = NSColor(red: 0.93, green: 0.92, blue: 0.89, alpha: on ? 0.95 : 0.14)
        if head { col = NSColor(red: 1, green: 0.373, blue: 0.122, alpha: 1) }
        ctx.setStrokeColor(col.cgColor); ctx.setLineWidth(head ? 17 : 13); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 512 + cos(a) * (r - len), y: 512 + sin(a) * (r - len)))
        ctx.addLine(to: CGPoint(x: 512 + cos(a) * r, y: 512 + sin(a) * r))
        ctx.strokePath()
    }
    // Orange core
    ctx.setFillColor(NSColor(red: 1, green: 0.373, blue: 0.122, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: 512 - 64, y: 512 - 64, width: 128, height: 128))
    ctx.setFillColor(NSColor(red: 0.078, green: 0.039, blue: 0.016, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: 512 - 22, y: 512 - 22, width: 44, height: 44))
    return true
}
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
