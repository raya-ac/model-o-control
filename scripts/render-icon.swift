import AppKit
import Foundation

guard CommandLine.arguments.count == 4 else {
    fputs("usage: render-icon.swift <master-image> <iconset-directory> <icns-file>\n", stderr)
    exit(2)
}

let masterURL = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let icnsOutput = URL(fileURLWithPath: CommandLine.arguments[3])
guard let master = NSImage(contentsOf: masterURL) else {
    fputs("could not load icon master at \(masterURL.path)\n", stderr)
    exit(2)
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
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

for (name, size) in variants {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Could not create bitmap") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = size <= 32 ? .high : .high

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let scale = CGFloat(size) / 1024
    let tileRect = canvas.insetBy(dx: 54 * scale, dy: 54 * scale)
    let tile = NSBezierPath(
        roundedRect: tileRect,
        xRadius: 218 * scale,
        yRadius: 218 * scale
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
    shadow.shadowBlurRadius = 34 * scale
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.set()
    NSColor.black.setFill()
    tile.fill()

    NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    master.draw(
        in: tileRect,
        from: NSRect(origin: .zero, size: master.size),
        operation: .copy,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    try data.write(to: output.appendingPathComponent(name), options: .atomic)
}

let chunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for (type, filename) in chunks {
    let png = try Data(contentsOf: output.appendingPathComponent(filename))
    body.append(type.data(using: .ascii)!)
    var chunkLength = UInt32(png.count + 8).bigEndian
    withUnsafeBytes(of: &chunkLength) { body.append(contentsOf: $0) }
    body.append(png)
}

var icns = Data("icns".utf8)
var totalLength = UInt32(body.count + 8).bigEndian
withUnsafeBytes(of: &totalLength) { icns.append(contentsOf: $0) }
icns.append(body)
try icns.write(to: icnsOutput, options: .atomic)
