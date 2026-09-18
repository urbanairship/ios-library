/* Copyright Airship and Contributors */

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@_spi(AirshipInternal) import AirshipBasement

/// Resolves the shared `test-layout.internal` placeholder convention (also implemented on
/// Android and web) into a locally synthesized image, so a scene authored against a specific
/// aspect ratio renders the same way whether it's opened by hand in the Layout Viewer or
/// captured by a UI test — no network, no third-party photo service.
///
/// URL shape: `https://test-layout.internal/{width}/{height}/{color}/{border}`, where `width`/
/// `height`/`border` are points (unscaled) and `color` is one of the names in `namedColors`.
enum TestLayoutPlaceholder {
    private static let host = "test-layout.internal"

    // Fixed RGB, not a system/dynamic color: Android and web resolve the same names to these
    // same hex values, so a placeholder looks the same regardless of which platform drew it.
    // Force-unwrapped: each is a literal AirshipColor already knows how to parse.
    private static let namedColors: [String: AirshipNativeColor] = [
        "red": AirshipColor.resolveNativeColor("F44336")!,
        "orange": AirshipColor.resolveNativeColor("FF9800")!,
        "yellow": AirshipColor.resolveNativeColor("FFEB3B")!,
        "green": AirshipColor.resolveNativeColor("4CAF50")!,
        "teal": AirshipColor.resolveNativeColor("009688")!,
        "blue": AirshipColor.resolveNativeColor("2196F3")!,
        "purple": AirshipColor.resolveNativeColor("9C27B0")!,
        "pink": AirshipColor.resolveNativeColor("E91E63")!,
        "gray": AirshipColor.resolveNativeColor("9E9E9E")!,
        "grey": AirshipColor.resolveNativeColor("9E9E9E")!,
    ]

    /// The local image URL for `urlString`, or nil if it isn't a `test-layout.internal` URL.
    static func resolve(urlString: String) -> URL? {
        guard
            let url = URL(string: urlString),
            url.host == host
        else {
            return nil
        }

        let components = url.pathComponents.filter { $0 != "/" }
        guard
            components.count >= 4,
            let width = Double(components[0]),
            let height = Double(components[1]),
            let border = Double(components[3])
        else {
            return nil
        }

        return try? renderedImageURL(
            width: width,
            height: height,
            color: components[2],
            border: border
        )
    }

    /// Writes (or reuses) a PNG at exactly `width`x`height`, keyed by its parameters so repeated
    /// requests for the same placeholder in one run don't re-render it.
    private static func renderedImageURL(
        width: Double,
        height: Double,
        color: String,
        border: Double
    ) throws -> URL {
        let fileName = "test-layout-\(Int(width))x\(Int(height))-\(color)-\(Int(border)).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        guard !FileManager.default.fileExists(atPath: url.path) else {
            return url
        }

        let size = CGSize(width: width, height: height)
        let fill = namedColors[color.lowercased()] ?? AirshipColor.resolveNativeColor("9E9E9E")!

        guard let data = renderPNG(size: size, draw: { cg in
            let bounds = CGRect(origin: .zero, size: size)

            cg.setFillColor(fill.withAlphaComponent(0.35).cgColor)
            cg.fill(bounds)

            // Off-center, so a crop's origin is visible in a screenshot, not just its aspect ratio.
            let markerSide = min(width, height) * 0.5
            cg.setFillColor(fill.cgColor)
            cg.fillEllipse(in: CGRect(
                x: width * 0.15,
                y: height * 0.15,
                width: markerSide,
                height: markerSide
            ))

            if border > 0 {
                cg.setStrokeColor(fill.cgColor)
                cg.setLineWidth(border)
                cg.stroke(bounds)
            }
        }) else {
            throw AirshipErrors.error("Failed to render test-layout placeholder")
        }

        try data.write(to: url)
        return url
    }

    /// Draws into a top-left-origin bitmap context of exactly `size` and returns it as PNG data.
    private static func renderPNG(size: CGSize, draw: (CGContext) -> Void) -> Data? {
#if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            draw(context.cgContext)
        }
#elseif canImport(AppKit)
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(size.width),
                pixelsHigh: Int(size.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext
        else {
            return nil
        }

        // NSGraphicsContext is bottom-left origin; flip to match UIKit's top-left convention so
        // the same draw closure places things the same way on both platforms.
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        draw(context)

        return bitmap.representation(using: .png, properties: [:])
#endif
    }
}
