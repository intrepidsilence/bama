#!/usr/bin/env swift
// Renders icon layers for the platforms that take image stacks (tvOS, visionOS)
// from the same SVG art as the Icon Composer file, and joins layers into a flat
// preview. Every path is given by the caller: layers go into the asset catalog,
// previews into the project's .work/icon/ folder.
//
//   swift render_layer.swift layer   in.svg out.png width height [--fit 0.6]
//       the SVG drawn centered, aspect kept, at --fit of the shorter side
//       (default 1), on a transparent canvas of width x height pixels
//   swift render_layer.swift fill    out.png width height RRGGBB
//       an opaque one-color back layer
//   swift render_layer.swift preview out.png back.png [middle.png ...] front.png
//       the layers stacked flat, back first; no mask, no parallax, no glass

import AppKit
import Foundation

let args = Array(CommandLine.arguments.dropFirst())

func option(_ name: String, _ fallback: Double) -> Double {
    guard let i = args.firstIndex(of: name), i + 1 < args.count, let value = Double(args[i + 1]) else { return fallback }
    return value
}

func canvas(_ width: Int, _ height: Int, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSRect(x: 0, y: 0, width: width, height: height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ path: String) {
    do {
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) (\(rep.pixelsWide) x \(rep.pixelsHigh) px)")
    } catch {
        print("cannot write \(path): \(error)"); exit(1)
    }
}

func load(_ path: String) -> NSImage {
    guard let image = NSImage(contentsOf: URL(fileURLWithPath: path)) else { print("cannot read \(path)"); exit(1) }
    return image
}

let usage = "usage: swift render_layer.swift layer in.svg out.png width height [--fit 0.6] | fill out.png width height RRGGBB | preview out.png back.png ... front.png"

switch args.first {
case "layer" where args.count >= 5:
    let image = load(args[1])
    guard let width = Int(args[3]), let height = Int(args[4]) else { print(usage); exit(1) }
    let fit = option("--fit", 1)
    let side = Double(min(width, height)) * fit
    let scale = side / max(image.size.width, image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    save(canvas(width, height) { rect in
        image.draw(in: NSRect(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2,
                              width: size.width, height: size.height))
    }, args[2])
case "fill" where args.count >= 5:
    guard let width = Int(args[2]), let height = Int(args[3]), let hex = UInt32(args[4], radix: 16) else {
        print(usage); exit(1)
    }
    let color = NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                        blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    save(canvas(width, height) { rect in color.setFill(); rect.fill() }, args[1])
case "preview" where args.count >= 3:
    let layers = args.dropFirst(2).map(load)
    guard let back = layers.first?.representations.first else { print(usage); exit(1) }
    save(canvas(back.pixelsWide, back.pixelsHigh) { rect in
        for layer in layers { layer.draw(in: rect) }
    }, args[1])
default:
    print(usage); exit(1)
}
