/* Copyright Airship and Contributors */

import ImageIO

/**
 * @note For internal use only. :nodoc:
 */
extension UIImage {
    class func duration(fromProperties properties: CFDictionary?) -> TimeInterval {
        var duration: TimeInterval = 0
        
        if let properties = properties {
            let frameProperties = properties as? [AnyHashable : Any]
            let gifProperties = frameProperties?[kCGImagePropertyGIFDictionary as String] as? [AnyHashable : Any]
            
            duration = TimeInterval((gifProperties?[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber)?.doubleValue ?? 0.0)
            if duration == 0.0 {
                duration = TimeInterval((gifProperties?[kCGImagePropertyGIFDelayTime as String] as? NSNumber)?.doubleValue ?? 0.0)
            }
        }
        
        return duration
    }
    
    
    class func animatedImage(with source: CGImageSource?, fillIn: Bool) -> UIImage? {
        var images: [AnyHashable] = []
        var fullDuration: TimeInterval = 0
        
        if let source = source {
            for i in 0..<CGImageSourceGetCount(source) {
                let imageRef = CGImageSourceCreateImageAtIndex(source, i, nil)
                if imageRef == nil {
                    continue
                }
                
                let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil)
                let duration = duration(fromProperties: properties)
                
                var image: UIImage? = nil
                if let imageRef = imageRef {
                    image = UIImage(cgImage: imageRef)
                }
                
                if image != nil && duration != 0.0 {
                    fullDuration += duration
                    
                    if (fillIn) {
                        // Fill in frames for every centisecond
                        let centiseconds = Int(duration * 100)
                        for _ in 0..<centiseconds {
                            if let image = image {
                                images.append(image)
                            }
                        }
                    } else {
                        images.append(image)
                    }
                }
            }
        }
        
        if let images = images as? [UIImage] {
            return self.animatedImage(with: images, duration: fullDuration)
        }
        return nil
    }
    
    /**
     * Image factory method that supports animated data.
     * - Parameters:
     *   - data The data.
     *   - fillIn: If the images should be expanded to fill in the frames for smoother animations in UIKit.
     * - Returns: The animated image if it is a gif, otherwise the still frame will be loaded.
     */
    @objc(fancyImageWithData:fillIn:)
    public class func fancyImage(with data: Data?, fillIn: Bool) -> UIImage? {
        var source: CGImageSource? = nil
        if let data = data {
            source = CGImageSourceCreateWithData(data as CFData, nil)
        }
        
        var image: UIImage?
        if let source = source {
            if (CGImageSourceGetCount(source) > 1) {
                image = self.animatedImage(with: source, fillIn: fillIn)
            } else {
                if let data = data {
                    image = self.init(data: data)
                }
            }
        }
        
        return image
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

