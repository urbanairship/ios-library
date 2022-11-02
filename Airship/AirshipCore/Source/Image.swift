/* Copyright Airship and Contributors */

import ImageIO

/**
 * @note For internal use only. :nodoc:
 */
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

        if imageData.frames.count > 1 {
            var totalDuration: TimeInterval = 0.0
            var images: [UIImage] = []

            imageData.frames.forEach { frame in
                if (frame.duration > 0.0) {
                    totalDuration += frame.duration
                }

                if (fillIn) {
                    let centiseconds = Int(frame.duration * 100)
                    for _ in 0..<centiseconds {
                        images.append(frame.image)
                    }
                } else {
                    images.append(frame.image)
                }
            }
            return UIImage.animatedImage(with: images, duration: totalDuration)
        } else {
            return imageData.frames[0].image
        }
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

    let frames: [Frame]
    private static let minFrameDuration: TimeInterval = 0.1
    
    init(frames: [Frame]) {
        self.frames = frames
    }

    @objc
    public convenience init(data: Data) throws {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw AirshipErrors.error("Invalid image data")
        }

        let frames = AirshipImageData.frames(from: source)
        if (frames.isEmpty) {
            throw AirshipErrors.error("Invalid image, no frames.")
        }

        self.init(frames: frames)
    }

    private class func frames(from source: CGImageSource) -> [Frame] {
        let count = CGImageSourceGetCount(source)
        guard count > 1 else {
            if let image = frameImage(0, source: source) {
                return [Frame(image: image, duration: 0.0)]
            } else {
                return []
            }
        }

        var frames: [Frame] = []
        for i in 0..<count {
            guard let image = frameImage(i, source: source) else {
                continue
            }

            frames.append(
                Frame(
                    image: image,
                    duration: frameDuration(i, source: source)
                )
            )
        }
        return frames
    }

    private static func frameImage(_ index: Int, source: CGImageSource) -> UIImage? {
        guard let imageRef = CGImageSourceCreateImageAtIndex(source, index, nil) else {
            return nil
        }

        return UIImage(cgImage: imageRef)
    }

    private static func frameDuration(
        _ index: Int,
        source: CGImageSource
    ) -> TimeInterval {

        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [AnyHashable: Any] else {
            return minFrameDuration
        }

        guard let gifProperties = properties[kCGImagePropertyGIFDictionary as String] as? [AnyHashable : Any]
        else {
            return minFrameDuration
        }

        var delayTime: TimeInterval? = nil

        if #available(iOS 13.0, *) {
            delayTime = gifProperties[kCGImageAnimationDelayTime as String] as? TimeInterval
        }

        let gifDelayTime = gifProperties[[kCGImagePropertyGIFUnclampedDelayTime as String]] as? TimeInterval

        return max(gifDelayTime ?? delayTime ?? 0.0, minFrameDuration)
    }
}

