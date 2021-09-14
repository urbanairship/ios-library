/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UAColorUtils)
public class ColorUtils : NSObject {
    
    @objc(colorWithHexString:)
    public class func color(_ hexString: String) -> UIColor? {
        var string = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        if string.hasPrefix("#") {
            let start = string.index(string.startIndex, offsetBy: 1)
            let range = start..<string.endIndex

            string = String(string[range])
        }
        
        let width = 8 * (string.count / 2)
        if (width != 32 && width != 24) {
            AirshipLogger.error("Invalid hex color string: \(string) (must be 24 or 32 bits wide)")
            return nil
        }
        
        var component: UInt64 = 0
        let scanner = Scanner.init(string: string)
        if (!scanner.scanHexInt64(&component)) {
            AirshipLogger.error("Unable to scan hexString: \(string)")
            return nil
        }
        
        let red: CGFloat = CGFloat(((component & 0xFF0000) >> 16))/255.0
        let green: CGFloat = CGFloat(((component & 0xFF00) >> 8))/255.0
        let blue: CGFloat =  CGFloat((component & 0xFF))/255.0
        let alpha: CGFloat = (width == 24) ? 1.0 : CGFloat(((component & 0xFF000000) >> 24))/255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    @objc(hexStringWithColor:)
    public class func hexString(_ color: UIColor) -> String? {
        var red = 0.0 as CGFloat
        var green = 0.0 as CGFloat
        var blue = 0.0 as CGFloat
        var alpha = 0.0 as CGFloat
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(255.0 * red)
        let g = Int(255.0 * green)
        let b = Int(255.0 * blue)
        let a = Int(255.0 * alpha)
        
        return String(format: "#%02x%02x%02x%02x", a, r , g, b)
    }
}
