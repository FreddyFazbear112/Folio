import AppKit
import Foundation

guard CommandLine.arguments.count > 1 else { fatalError("Missing output path") }
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)
let bounds = CGRect(x: 0, y: 0, width: size, height: size)

let background = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.12, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.075, green: 0.13, blue: 0.22, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.018, green: 0.035, blue: 0.085, alpha: 1).cgColor
] as CFArray, locations: [0, 0.52, 1])!
context.drawRadialGradient(background, startCenter: CGPoint(x: 512, y: 720), startRadius: 10, endCenter: CGPoint(x: 512, y: 500), endRadius: 780, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Restrained celestial halo.
context.setStrokeColor(NSColor(calibratedRed: 0.88, green: 0.67, blue: 0.34, alpha: 0.22).cgColor)
context.setLineWidth(3)
context.strokeEllipse(in: CGRect(x: 184, y: 184, width: 656, height: 656))
context.setStrokeColor(NSColor(calibratedRed: 0.88, green: 0.67, blue: 0.34, alpha: 0.12).cgColor)
context.setLineWidth(1.5)
context.strokeEllipse(in: CGRect(x: 222, y: 222, width: 580, height: 580))

// Small northern star.
let star = NSBezierPath()
star.move(to: CGPoint(x: 512, y: 824)); star.line(to: CGPoint(x: 520, y: 804))
star.line(to: CGPoint(x: 540, y: 796)); star.line(to: CGPoint(x: 520, y: 788))
star.line(to: CGPoint(x: 512, y: 768)); star.line(to: CGPoint(x: 504, y: 788))
star.line(to: CGPoint(x: 484, y: 796)); star.line(to: CGPoint(x: 504, y: 804)); star.close()
NSColor(calibratedRed: 0.96, green: 0.79, blue: 0.48, alpha: 0.9).setFill()
star.fill()

// Open book silhouette, warm gilded edges.
let book = CGMutablePath()
book.move(to: CGPoint(x: 512, y: 306))
book.addCurve(to: CGPoint(x: 256, y: 382), control1: CGPoint(x: 414, y: 334), control2: CGPoint(x: 326, y: 352))
book.addLine(to: CGPoint(x: 256, y: 650))
book.addCurve(to: CGPoint(x: 492, y: 584), control1: CGPoint(x: 342, y: 628), control2: CGPoint(x: 426, y: 590))
book.addCurve(to: CGPoint(x: 512, y: 574), control1: CGPoint(x: 501, y: 578), control2: CGPoint(x: 507, y: 574))
book.addCurve(to: CGPoint(x: 532, y: 584), control1: CGPoint(x: 517, y: 574), control2: CGPoint(x: 523, y: 578))
book.addCurve(to: CGPoint(x: 768, y: 650), control1: CGPoint(x: 598, y: 590), control2: CGPoint(x: 682, y: 628))
book.addLine(to: CGPoint(x: 768, y: 382))
book.addCurve(to: CGPoint(x: 512, y: 306), control1: CGPoint(x: 698, y: 352), control2: CGPoint(x: 610, y: 334))
book.closeSubpath()
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -18), blur: 35, color: NSColor.black.withAlphaComponent(0.55).cgColor)
let gold = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(calibratedRed: 1, green: 0.88, blue: 0.62, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.68, green: 0.43, blue: 0.19, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.96, green: 0.76, blue: 0.42, alpha: 1).cgColor
] as CFArray, locations: [0, 0.5, 1])!
context.addPath(book)
context.clip()
context.drawLinearGradient(gold, start: CGPoint(x: 256, y: 650), end: CGPoint(x: 768, y: 306), options: [])
context.restoreGState()

// Deep ink pages with a warm central gutter.
let left = NSBezierPath()
left.move(to: CGPoint(x: 282, y: 405)); left.curve(to: CGPoint(x: 493, y: 554), controlPoint1: CGPoint(x: 365, y: 384), controlPoint2: CGPoint(x: 455, y: 500))
left.line(to: CGPoint(x: 493, y: 345)); left.curve(to: CGPoint(x: 282, y: 418), controlPoint1: CGPoint(x: 420, y: 360), controlPoint2: CGPoint(x: 342, y: 394)); left.close()
let right = NSBezierPath()
right.move(to: CGPoint(x: 531, y: 554)); right.curve(to: CGPoint(x: 742, y: 405), controlPoint1: CGPoint(x: 569, y: 500), controlPoint2: CGPoint(x: 659, y: 384))
right.line(to: CGPoint(x: 742, y: 418)); right.curve(to: CGPoint(x: 531, y: 345), controlPoint1: CGPoint(x: 681, y: 394), controlPoint2: CGPoint(x: 603, y: 360)); right.close()
NSColor(calibratedRed: 0.055, green: 0.10, blue: 0.17, alpha: 1).setFill(); left.fill(); right.fill()

// Fine page rules.
context.setStrokeColor(NSColor(calibratedRed: 0.91, green: 0.72, blue: 0.43, alpha: 0.72).cgColor)
context.setLineWidth(3)
for y in [448.0, 474.0, 500.0] {
    context.move(to: CGPoint(x: 322, y: y)); context.addLine(to: CGPoint(x: 452, y: y + 64))
    context.move(to: CGPoint(x: 572, y: y + 64)); context.addLine(to: CGPoint(x: 702, y: y))
}
context.strokePath()
context.setStrokeColor(NSColor(calibratedRed: 1, green: 0.88, blue: 0.65, alpha: 0.95).cgColor)
context.setLineWidth(5)
context.move(to: CGPoint(x: 512, y: 322)); context.addLine(to: CGPoint(x: 512, y: 570)); context.strokePath()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Could not encode icon") }
try png.write(to: output)
