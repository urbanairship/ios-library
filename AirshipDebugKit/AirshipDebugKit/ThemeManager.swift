/* Copyright Airship and Contributors */

import UIKit

/*
 * Manages color themes optionally loaded from a plist and
 * acts as a unified source for theme colors.
 */
class ThemeManager: NSObject {
    static let shared = ThemeManager()
    var currentTheme = Theme()

    override init() {
        super.init()
        self.loadThemePlistFromBundle(bundle:Bundle.main)
    }

    func loadThemePlistFromBundle(bundle:Bundle) {
        guard let path = bundle.path(forResource:"DebugKitTheme", ofType: "plist") else {
            // theme not found, use default theme
            return
        }

        guard let colorOverrides:[String:String] = NSDictionary(contentsOfFile:path) as? [String:String] else {
            // plist improperly defined, use default theme
            return
        }

        for (colorPropertyName, defaultColor) in currentTheme.allColors() {
            guard let overrideColorString = colorOverrides[colorPropertyName] else {
                // overriding color not specified for default theme color
                continue
            }

            if let overrideColor = hexToColor(hexString:overrideColorString) {
                print("🎨 ThemeManager - Overriding default theme color \(colorPropertyName) - \(defaultColor.toHexString()) with \(overrideColorString)")
                currentTheme.setValue(overrideColor, forKeyPath:colorPropertyName)
            }
        }
    }

    func hexToColor(hexString:String) -> UIColor? {
        var hexString = hexString.trimmingCharacters(in:.whitespacesAndNewlines).uppercased()

        if (hexString.hasPrefix("#")) {
            hexString.remove(at: hexString.startIndex)
        }

        if hexString.count != 6 {
            return nil
        }

        var rgbValue:UInt32 = 0
        Scanner(string:hexString).scanHexInt32(&rgbValue)

        return UIColor(
            red:CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green:CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue:CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha:CGFloat(1.0)
        )
    }
}

extension Theme {
    // Extend DebugKitColorTheme to use reflection to make enumerable color dictionary
    func allColors() -> [String:UIColor] {
        var allColors: [String:UIColor] = [:]
        let mirror = Mirror(reflecting:self)

        //guard let style = mirror.displayStyle, style == .Struct else { return }
        for (colorName, color) in mirror.children {
            guard let colorName = colorName else { continue }
            guard let color = color as? UIColor else { continue }

            allColors[colorName] = color
        }

        return allColors
    }
}

extension UIColor {
    convenience init(red:Int, green:Int, blue:Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(rgb:Int) {
        self.init(
            red: (rgb >> 16) & 0xFF,
            green: (rgb >> 8) & 0xFF,
            blue: rgb & 0xFF
        )
    }

    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0

        return String(format:"#%06x", rgb)
    }
}
