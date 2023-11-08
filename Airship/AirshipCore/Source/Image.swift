/* Copyright Airship and Contributors */

import ImageIO

/// @note For internal use only. :nodoc:
extension UIImage {
    /**
     * Image factory method that supports animated data.
     * - Parameters:
     *   - data The data.
     *   - fillIn: If the images should be expanded to fill in the frames for smoother animations in UIKit.
     * - Returns: The animated image if it is a gif, otherwise the still frame will be loaded.
     */
    @objc(fancyImageWithData:fillIn:)
    public class func fancyImage(with data: Data?, fillIn: Bool) -> UIImage? {
        guard let data = data,
            let imageData = try? AirshipImageData(data: data)
        else {
            return nil
        }

        guard imageData.isAnimated else {
            return imageData.loadFrames()[0].image
        }
        var totalDuration: TimeInterval = 0.0
        var images: [UIImage] = []

        imageData.loadFrames().forEach { frame in
            if frame.duration > 0.0 {
                totalDuration += frame.duration
            }

            if fillIn {
                let centiseconds = Int(frame.duration * 100)
                for _ in 0..<centiseconds {
                    images.append(frame.image)
                }
            } else {
                images.append(frame.image)
            }
        }
        return UIImage.animatedImage(with: images, duration: totalDuration)
    }

    /**
     * Image factory method that supports animated data.
     * - Parameters:
     *   - data The data.
     * - Returns: The animated image if it is a gif, otherwise the still frame will be loaded.
     */
    @objc(fancyImageWithData:)
    public class func fancyImage(with data: Data?) -> UIImage? {
        return fancyImage(with: data, fillIn: true)
    }
}

/// - Note: for internal use only.  :nodoc:
@objc(UAirshipImageData)
public class AirshipImageData: NSObject {
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

    init(_ source: CGImageSource) throws {
        self.source = source
        imageFramesCount = CGImageSourceGetCount(source)
        if imageFramesCount < 1 {
            throw AirshipErrors.error("Invalid image, no frames.")
        }
        
        self.isAnimated = imageFramesCount > 1
        self.imageActor = AirshipImageDataFrameActor(source: source)
    }

    @objc
    public convenience init(data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            throw AirshipErrors.error("Invalid image data")
        }
        
        try self.init(source)
    }
    
    func loadFrames() -> [Frame] {
        return Self.frames(from: source)
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
