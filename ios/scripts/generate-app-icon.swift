// Run from the repository root: swift ios/scripts/generate-app-icon.swift
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("reelsbanlogo.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let logo = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Cannot read reelsbanlogo.png")
}
precondition(logo.width == 1024 && logo.height == 1024, "Logo must be 1024×1024")
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("ios/App/Assets.xcassets")
let output = root.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let info: [String: Any] = ["author": "xcode", "version": 1]
try JSONSerialization.data(withJSONObject: ["info": info], options: [.prettyPrinted, .sortedKeys])
    .write(to: root.appendingPathComponent("Contents.json"))
var images: [[String: String]] = []
let slots: [(String, Double, [Int])] = [
    ("iphone", 20, [2, 3]), ("iphone", 29, [2, 3]),
    ("iphone", 40, [2, 3]), ("iphone", 60, [2, 3]),
    ("ipad", 20, [1, 2]), ("ipad", 29, [1, 2]),
    ("ipad", 40, [1, 2]), ("ipad", 76, [1, 2]),
    ("ipad", 83.5, [2]), ("ios-marketing", 1024, [1])
]
var rendered = Set<Int>()
for (idiom, points, scales) in slots {
    for scale in scales {
        let pixels = Int(points * Double(scale))
        let filename = "Icon-\(pixels).png"
        let size = points == points.rounded() ? String(Int(points)) : String(points)
        images.append(["idiom": idiom, "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
        guard rendered.insert(pixels).inserted else { continue }
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
            bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        let side = CGFloat(pixels)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .high
        context.draw(logo, in: CGRect(x: 0, y: 0, width: side, height: side))
        let destination = CGImageDestinationCreateWithURL(output.appendingPathComponent(filename) as CFURL,
            UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
    }
}
try JSONSerialization.data(withJSONObject: ["images": images, "info": info], options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
