/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS)

import CoreGraphics
import SwiftUI

@testable import AirshipSceneRenderer

/// Renders `view` to a real bitmap at `size` and returns its raw RGBA8 bytes, so a test can
/// sample actual pixels rather than reason about what SwiftUI is documented to do.
@MainActor
func renderPixels(_ view: some View, size: CGSize) -> [UInt8]? {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 1
    guard let cgImage = renderer.cgImage else { return nil }

    let width = Int(size.width)
    let height = Int(size.height)
    var pixelData = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(
        data: &pixelData,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    return pixelData
}

/// One pixel's sRGB components (0-1), read from a buffer `renderPixels` produced.
func pixel(_ buffer: [UInt8], width: Int, x: Int, y: Int) -> (r: Double, g: Double, b: Double, a: Double) {
    let offset = (y * width + x) * 4
    return (
        Double(buffer[offset]) / 255.0,
        Double(buffer[offset + 1]) / 255.0,
        Double(buffer[offset + 2]) / 255.0,
        Double(buffer[offset + 3]) / 255.0
    )
}

#endif
