// Regenerates the LOOP launcher/app icons from the frozen prototype brand asset
// docs/prototype/assets/brand/loop-app-icon.svg (identical to assets/brand/loop-app-icon.svg).
//
// The prototype mark is: an Ink (#050604) rounded square with a Graphite (#171A16)
// hairline, carrying an infinity glyph stroked Graphite 25 / Chalk 18 / Lime 4 with a
// Lime dot at the crossing, inside a 128x128 design box.
//
// Android adaptive icons must NOT bake any plate into the foreground layer: the
// foreground is the glyph only on full transparency, sized to the 66dp Material
// keyline circle of the 108dp canvas so neither the launcher mask nor the
// Android 12+ splash mask can clip it.
//
// Usage (from loop-mobile/):
//   swift tool/brand/render_app_icon.swift
//
// swiftformat/analyze do not cover this file; it is a build-time asset generator.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Brand tokens (lib/core/theme + assets/brand/loop-app-icon.svg)

let ink = CGColor(srgbRed: 0x05 / 255, green: 0x06 / 255, blue: 0x04 / 255, alpha: 1)
let graphite = CGColor(srgbRed: 0x17 / 255, green: 0x1A / 255, blue: 0x16 / 255, alpha: 1)
let chalk = CGColor(srgbRed: 0xF3 / 255, green: 0xF5 / 255, blue: 0xEF / 255, alpha: 1)
let lime = CGColor(srgbRed: 0xB8 / 255, green: 0xFF / 255, blue: 0x20 / 255, alpha: 1)

// MARK: - Geometry, in the SVG's 128x128 design box

/// The infinity path from loop-app-icon.svg, expanded from its relative/smooth form.
func infinityPath() -> CGPath {
  let p = CGMutablePath()
  p.move(to: CGPoint(x: 64, y: 64))
  p.addCurve(to: CGPoint(x: 19, y: 64), control1: CGPoint(x: 53, y: 40), control2: CGPoint(x: 19, y: 40))
  p.addCurve(to: CGPoint(x: 64, y: 64), control1: CGPoint(x: 19, y: 88), control2: CGPoint(x: 53, y: 88))
  p.addCurve(to: CGPoint(x: 109, y: 64), control1: CGPoint(x: 75, y: 40), control2: CGPoint(x: 109, y: 40))
  p.addCurve(to: CGPoint(x: 64, y: 64), control1: CGPoint(x: 109, y: 88), control2: CGPoint(x: 75, y: 88))
  return p
}

/// Stroked width of the glyph in design units: centreline spans x 19...109, the
/// widest stroke is 25 with round caps, so 90 + 25 = 115. Because the glyph's
/// extreme points sit on the horizontal centre line, 115 is also the diameter of
/// its circumscribed circle -- which is what the adaptive/splash masks clip to.
let glyphDesignWidth: CGFloat = 115

/// Draws the glyph so that its stroked width equals `width`, centred on `centre`.
func drawGlyph(_ ctx: CGContext, centre: CGPoint, width: CGFloat) {
  let k = width / glyphDesignWidth
  ctx.saveGState()
  ctx.translateBy(x: centre.x, y: centre.y)
  ctx.scaleBy(x: k, y: -k)  // flip: design box is y-down, CG bitmaps are y-up
  ctx.translateBy(x: -64, y: -64)
  strokeGlyphInDesignSpace(ctx)
  ctx.restoreGState()
}

func strokeGlyphInDesignSpace(_ ctx: CGContext) {
  let path = infinityPath()
  ctx.setLineCap(.round)
  ctx.setLineJoin(.round)
  for (color, lineWidth) in [(graphite, CGFloat(25)), (chalk, CGFloat(18)), (lime, CGFloat(4))] {
    ctx.setStrokeColor(color)
    ctx.setLineWidth(lineWidth)
    ctx.addPath(path)
    ctx.strokePath()
  }
  ctx.setFillColor(lime)
  ctx.fillEllipse(in: CGRect(x: 60, y: 60, width: 8, height: 8))
}

// MARK: - Canvases

func makeContext(_ size: Int, opaque: Bool) -> CGContext {
  let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast
  let ctx = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: alpha.rawValue)!
  ctx.setAllowsAntialiasing(true)
  ctx.setShouldAntialias(true)
  return ctx
}

func write(_ ctx: CGContext, to path: String) {
  let url = URL(fileURLWithPath: path)
  try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
  precondition(CGImageDestinationFinalize(dest), "failed to write \(path)")
  print("wrote \(path) (\(ctx.width)x\(ctx.height))")
}

/// Adaptive-icon foreground layer: glyph only, fully transparent elsewhere.
/// 66dp keyline on the 108dp canvas keeps the mark inside the 72dp safe zone and
/// inside the Android 12+ splash mask (inner 2/3).
func renderAdaptiveForeground(_ size: Int, to path: String) {
  let ctx = makeContext(size, opaque: false)
  let s = CGFloat(size)
  drawGlyph(ctx, centre: CGPoint(x: s / 2, y: s / 2), width: s * 66 / 108)
  write(ctx, to: path)
}

/// Legacy (pre-API-26) launcher icon: the whole prototype tile, Ink plate included.
func renderLegacyLauncher(_ size: Int, to path: String) {
  let ctx = makeContext(size, opaque: false)
  let k = CGFloat(size) / 128
  ctx.saveGState()
  ctx.translateBy(x: 0, y: CGFloat(size))
  ctx.scaleBy(x: k, y: -k)
  let plate = CGPath(
    roundedRect: CGRect(x: 4, y: 4, width: 120, height: 120), cornerWidth: 32, cornerHeight: 32,
    transform: nil)
  ctx.addPath(plate)
  ctx.setFillColor(ink)
  ctx.fillPath()
  ctx.addPath(plate)
  ctx.setStrokeColor(graphite)
  ctx.setLineWidth(4)
  ctx.strokePath()
  strokeGlyphInDesignSpace(ctx)
  ctx.restoreGState()
  write(ctx, to: path)
}

/// iOS app icon: opaque, full bleed (the system applies the squircle mask itself).
func renderIosIcon(_ size: Int, to path: String) {
  let ctx = makeContext(size, opaque: true)
  let s = CGFloat(size)
  ctx.setFillColor(ink)
  ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
  drawGlyph(ctx, centre: CGPoint(x: s / 2, y: s / 2), width: s * 0.68)
  write(ctx, to: path)
}

// MARK: - Manifest

let root = FileManager.default.currentDirectoryPath
func at(_ rel: String) -> String { "\(root)/\(rel)" }

let androidDensities: [(String, Int, Int)] = [
  // bucket, adaptive foreground px (108dp), legacy launcher px (48dp)
  ("mdpi", 108, 48),
  ("hdpi", 162, 72),
  ("xhdpi", 216, 96),
  ("xxhdpi", 324, 144),
  ("xxxhdpi", 432, 192),
]
for (bucket, foreground, legacy) in androidDensities {
  let dir = "android/app/src/main/res/mipmap-\(bucket)"
  renderAdaptiveForeground(foreground, to: at("\(dir)/ic_launcher_foreground.png"))
  renderLegacyLauncher(legacy, to: at("\(dir)/ic_launcher.png"))
}

let iosIcons: [(String, Int)] = [
  ("Icon-App-20x20@1x.png", 20), ("Icon-App-20x20@2x.png", 40), ("Icon-App-20x20@3x.png", 60),
  ("Icon-App-29x29@1x.png", 29), ("Icon-App-29x29@2x.png", 58), ("Icon-App-29x29@3x.png", 87),
  ("Icon-App-40x40@1x.png", 40), ("Icon-App-40x40@2x.png", 80), ("Icon-App-40x40@3x.png", 120),
  ("Icon-App-60x60@2x.png", 120), ("Icon-App-60x60@3x.png", 180),
  ("Icon-App-76x76@1x.png", 76), ("Icon-App-76x76@2x.png", 152),
  ("Icon-App-83.5x83.5@2x.png", 167),
  ("Icon-App-1024x1024@1x.png", 1024),
]
for (name, size) in iosIcons {
  renderIosIcon(size, to: at("ios/Runner/Assets.xcassets/AppIcon.appiconset/\(name)"))
}
