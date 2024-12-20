/* Copyright Airship and Contributors */

import Foundation

#if canImport(UIKit)
import UIKit
#endif

@preconcurrency
import ImageIO

/// - Note: for internal use only.  :nodoc:
public final class AirshipImageData: @unchecked Sendable {
    // Image frame
    struct Frame {
        let image: UIImage
        let duration: TimeInterval
    }

    static let minFrameDuration: TimeInterval = 0.01
    private let source: CGImageSource
    private let imageActor: AirshipImageDataFrameActor
    
    let isAnimated: Bool
    let imageFramesCount: Int
    let loopCount: Int?

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

    func loadFrames() async -> [Frame] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let frames = Self.frames(from: self.source)
                DispatchQueue.main.async {
                    continuation.resume(returning: frames)
                }
            }
        }
    }

    func getActor() -> AirshipImageDataFrameActor {
        return self.imageActor
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
    
    fileprivate static func frameImage(_ index: Int, source: CGImageSource)
        -> UIImage?
    {
        guard let imageRef = CGImageSourceCreateImageAtIndex(source, index, nil)
        else {
            return nil
        }

        return UIImage(cgImage: imageRef)
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
