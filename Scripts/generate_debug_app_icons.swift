#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceDir = root.appendingPathComponent("CAP/Assets.xcassets/AppIcon.appiconset")
let destDir = root.appendingPathComponent("CAP/Assets.xcassets/AppIcon-Debug.appiconset")

func addYellowBar(to image: NSImage) -> NSImage {
    let size = image.size
    let result = NSImage(size: size)
    result.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: size))
    NSColor(red: 1, green: 0.78, blue: 0.05, alpha: 1).setFill()
    let barHeight = max(2, size.height * 0.11)
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: size.width, height: barHeight)).fill()
    result.unlockFocus()
    return result
}

func pngData(from image: NSImage) -> Data? {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return nil }
    return rep.representation(using: .png, properties: [:])
}

try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
let contentsSrc = sourceDir.appendingPathComponent("Contents.json")
let contentsDest = destDir.appendingPathComponent("Contents.json")
try Data(contentsOf: contentsSrc).write(to: contentsDest)

let contents = try JSONSerialization.jsonObject(with: Data(contentsOf: contentsSrc)) as! [String: Any]
let images = contents["images"] as! [[String: Any]]
for entry in images {
    guard let filename = entry["filename"] as? String else { continue }
    let src = sourceDir.appendingPathComponent(filename)
    let dst = destDir.appendingPathComponent(filename)
    guard let image = NSImage(contentsOf: src) else { continue }
    let stamped = addYellowBar(to: image)
    guard let data = pngData(from: stamped) else { continue }
    try data.write(to: dst)
}
print("Generated AppIcon-Debug.appiconset")
