/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

#if canImport(UIKit)
public import UIKit
public typealias AirshipNativeImage = UIImage
#elseif canImport(AppKit)
public import AppKit
public typealias AirshipNativeImage = NSImage
#endif

@preconcurrency
import ImageIO

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public final class AirshipImageData: Sendable {
    // Image frame
    public struct Frame: @unchecked Sendable {
        public let image: AirshipNativeImage
        public let duration: TimeInterval
    }

    public static let minFrameDuration: TimeInterval = 0.01
    private let source: CGImageSource
    private let imageActor: AirshipImageDataFrameActor

    public let isAnimated: Bool
    public let imageFramesCount: Int
    public let loopCount: Int?

    init(_ source: CGImageSource) throws {
        self.source = source
        imageFramesCount = CGImageSourceGetCount(source)
        if imageFramesCount < 1 {
            throw AirshipErrors.error("Invalid image, no frames.")
        }

        self.loopCount = source.gifLoopCount()
        self.isAnimated = imageFramesCount > 1
        self.imageActor = AirshipImageDataFrameActor(source: source)
    }

    public convenience init(data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            throw AirshipErrors.error("Invalid image data")
        }

        try self.init(source)
    }

    public func loadFrames() async -> [Frame] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let frames = Self.frames(from: self.source)
                DispatchQueue.main.async {
                    continuation.resume(returning: frames)
                }
            }
        }
    }

    public func loadFrame(at index: Int) async -> Frame? {
        await imageActor.loadFrame(at: index)
    }

    private class func frames(from source: CGImageSource) -> [Frame] {
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            guard let image = AirshipImageDataFrameActor.frameImage(0, source: source) else {
                return []
            }
            return [Frame(image: image, duration: 0.0)]
        }

        var frames: [Frame] = []
        for i in 0..<count {
            guard let image = AirshipImageDataFrameActor.frameImage(i, source: source) else {
                continue
            }

            frames.append(
                Frame(
                    image: image,
                    duration: AirshipImageDataFrameActor.frameDuration(i, source: source)
                )
            )
        }
        return frames
    }
}

actor AirshipImageDataFrameActor {
    private let source: CGImageSource

    let framesCount: Int

    init(source: CGImageSource) {
        self.source = source
        framesCount = CGImageSourceGetCount(source)
    }

    func loadFrame(at index: Int) -> AirshipImageData.Frame? {
        guard index >= 0, index < framesCount else { return nil }

        guard let image = Self.frameImage(index, source: source) else {
            return nil
        }

        return AirshipImageData.Frame(
            image: image,
            duration: Self.frameDuration(index, source: source)
        )
    }

    fileprivate static func frameImage(
        _ index: Int,
        source: CGImageSource
    ) -> AirshipNativeImage? {
        guard let imageRef = CGImageSourceCreateImageAtIndex(source, index, nil)
        else {
            return nil
        }
        // Use a cross-platform initializer
        return AirshipNativeImage.make(with: imageRef)
    }

    fileprivate static func frameDuration(
        _ index: Int,
        source: CGImageSource
    ) -> TimeInterval {

        guard
            let properties = imageProperties(index: index, source: source)
        else {
            return AirshipImageData.minFrameDuration
        }

        let delayTime = properties[kCGImageAnimationDelayTime as String] as? TimeInterval
        let gifDelayTime = properties[[kCGImagePropertyGIFUnclampedDelayTime as String]] as? TimeInterval

        return max(gifDelayTime ?? delayTime ?? 0.0, AirshipImageData.minFrameDuration)
    }

    fileprivate static func imageProperties(
        index: Int,
        source: CGImageSource
    ) -> [AnyHashable: Any]? {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(
                source,
                index,
                nil
            ) as? [AnyHashable: Any]
        else {
            return nil
        }

        let gif = properties[
            kCGImagePropertyGIFDictionary as String
        ] as? [AnyHashable: Any]

        let webp = properties[
            kCGImagePropertyWebPDictionary as String
        ] as? [AnyHashable: Any]

        return gif ?? webp
    }
}

extension CGImageSource {
    func gifLoopCount() -> Int? {
        guard let properties = CGImageSourceCopyProperties(self, nil) as NSDictionary?,
              let gifDictionary = properties[kCGImagePropertyGIFDictionary] as? NSDictionary else {
            return nil
        }

        let loopCount = gifDictionary[kCGImagePropertyGIFLoopCount] as? Int
        return loopCount
    }
}

fileprivate extension AirshipNativeImage {
    static func make(with cgImage: CGImage) -> AirshipNativeImage {
#if os(macOS)
        return NSImage(cgImage: cgImage, size: .zero) // .zero size uses the pixel dimensions
#else
        return UIImage(cgImage: cgImage)
#endif
    }
}

public extension Image {
    /// Bridges UIImage and NSImage into a single SwiftUI Image initializer
    init(airshipNativeImage: AirshipNativeImage) {
        #if os(macOS)
        self.init(nsImage: airshipNativeImage)
        #else
        self.init(uiImage: airshipNativeImage)
        #endif
    }
}

public extension AirshipNativeImage {
    /// Cross-platform initializer for SF Symbols
    static func airshipSystemImage(name: String) -> AirshipNativeImage? {
        #if os(macOS)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        #else
        return UIImage(systemName: name)
        #endif
    }
}
