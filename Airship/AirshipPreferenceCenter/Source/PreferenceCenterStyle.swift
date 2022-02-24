/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Preference center  style.
 */
@objc(UAPreferenceCenterStyle)
public class PreferenceCenterStyle : NSObject {
    /**
     * The title text.
     */
    @objc public var title: String?

    /**
     * The title font.
     */
    @objc public var titleFont: UIFont?

    /**
     * The title color.
     */
    @objc public var titleColor: UIColor?

    /**
     * The subtitle text.
     */
    @objc public var subtitle: String?

    /**
     * The subtitle font.
     */
    @objc public var subtitleFont: UIFont?

    /**
     * The subtitle color.
     */
    @objc public var subtitleColor: UIColor?
    
    /**
     * The section text color. Applies to both title and subtitle.
     */
    @objc public var sectionTextColor: UIColor?
    
    /**
     * The section title text font. Applies to both title and subtitle.
     */
    @objc public var sectionTextFont: UIFont?
    
    /**
     * The section title text color.
     */
    @objc public var sectionTitleTextColor: UIColor?
    
    /**
     * The section title text font.
     */
    @objc public var sectionTitleTextFont: UIFont?
    
    /**
     * The section subtitle text color.
     */
    @objc public var sectionSubtitleTextColor: UIColor?
    
    /**
     * The section subtitle text font.
     */
    @objc public var sectionSubtitleTextFont: UIFont?
    
    /**
     * The section break text color.
     */
    @objc public var sectionBreakTextColor: UIColor?
    
    /**
     * The section break text font.
     */
    @objc public var sectionBreakTextFont: UIFont?
    
    /**
     * The section break text color.
     */
    @objc public var sectionBreakBackgroundColor: UIColor?
    
    /**
     * The preference text color. Applies to both title, subtitle, and chips.
     */
    @objc public var preferenceTextColor: UIColor?

    /**
     * The preference text font. Applies to both title, subtitle, and chips.
     */
    @objc public var preferenceTextFont: UIFont?
    
    /**
     * The preference title text color.
     */
    @objc public var preferenceTitleTextColor: UIColor?

    /**
     * The preference title text font.
     */
    @objc public var preferenceTitleTextFont: UIFont?
    
    /**
     * The preference subtitle text color.
     */
    @objc public var preferenceSubtitleTextColor: UIColor?

    /**
     * The preference subtitle text font.
     */
    @objc public var preferenceSubtitleTextFont: UIFont?

    /**
     * The background color.
     */
    @objc public var backgroundColor: UIColor?

    /**
     * The navigation bar color.
     */
    @objc public var navigationBarColor: UIColor?

    /**
     * The navigation bar tint color.
     */
    @objc public var tintColor: UIColor?

    /**
     * The switch tint color when on
     */
    @objc public var switchTintColor: UIColor?

    /**
     * The switch thumb tint color
     */
    @objc public var switchThumbTintColor: UIColor?
    
    /**
     * The preference chip text color.
     */
    @objc public var preferenceChipTextColor: UIColor?

    /**
     * The preference chip text font.
     */
    @objc public var preferenceChipTextFont: UIFont?
    
    /**
     * The preference chip check mark color.
     */
    @objc public var preferenceChipCheckmarkColor: UIColor?
    
    /**
     * The preference chip check mark background color when unchecked.
     */
    @objc public var preferenceChipCheckmarkBackgroundColor: UIColor?
    
    /**
     * The preference chip check mark background color when checked.
     */
    @objc public var preferenceChipCheckmarkCheckedBackgroundColor: UIColor?
    
    /**
     * The preference chip border color.
     */
    @objc public var preferenceChipBorderColor: UIColor?
    
    /**
     * The alert title color
     */
    @objc public var alertTitleColor: UIColor?
    
    /**
     * The alert title font.
     */
    @objc public var alertTitleFont: UIFont?
    
    /**
     * The alert subtitle color.
     */
    @objc public var alertSubtitleColor: UIColor?
    
    /**
     * The alert subtitle font.
     */
    @objc public var alertSubtitleFont: UIFont?
    
    /**
     * The alert button background color.
     */
    @objc public var alertButtonBackgroundColor: UIColor?
    
    /**
     * The alert button label color.
     */
    @objc public var alertButtonLabelColor: UIColor?
    
    /**
     * The alert button label font.
     */
    @objc public var alertButtonLabelFont: UIFont?

    /**
     * Preference center style initializer
     */
    public override init() {
        super.init()
    }

    /**
     * Preference center style initializer for parsing from a plist.
     *
     * @param file The plist file to read from.
     */
    public init(file: String) {
        super.init()
        if let path = Bundle.main.path(forResource: file, ofType: "plist") {
            do {
                var format = PropertyListSerialization.PropertyListFormat.xml
                let xml = FileManager.default.contents(atPath: path)!
                let styleDict = try PropertyListSerialization.propertyList(from: xml, options: .mutableContainersAndLeaves, format: &format) as! [String:AnyObject]
                let normalized = normalize(keyedValues: styleDict)
                setValuesForKeys(normalized)

            } catch {
                AirshipLogger.error("Error reading preference center style plist: \(error)")
            }
        } else {
            AirshipLogger.error("Unable to find preference center plist file: \(file)")
        }
    }

    public override func setValue(_ value: Any?, forUndefinedKey key: String) {
        // Do not crash on undefined keys
        AirshipLogger.debug("Ignoring invalid preference center style key: \(key)")
    }

    private func normalize(keyedValues: [String : AnyObject]) -> [String : AnyObject] {
        var normalized: [String : AnyObject] = [:]

        for (key, value) in keyedValues {
            var normalizedValue: AnyObject?

            // Trim whitespace
            if let stringValue = value as? String {
                normalizedValue = stringValue.trimmingCharacters(in: .whitespaces) as AnyObject
            }

            // Normalize colors
            if key.hasSuffix("Color") {
                if let colorString = value as? String {
                    normalizedValue = createColor(string: colorString)
                    normalized[key] = normalizedValue
                }

                continue
            }

            // Normalize fonts
            if key.hasSuffix("Font") {
                if let fontDict = value as? [String : String] {
                    normalizedValue = createFont(dict: fontDict)
                    normalized[key] = normalizedValue
                }

                continue
            }

            normalized[key] = normalizedValue
        }


        return normalized
    }

    private func createColor(string: String) -> UIColor? {
        let hexColor = ColorUtils.color(string)
        let namedColor = UIColor(named: string)

        guard hexColor != nil || namedColor != nil else {
            AirshipLogger.error("Color must be a valid string representing either a valid color hexidecimal or a named color corresponding to a color asset in the main bundle.")

            return nil
        }

        return namedColor != nil ? namedColor : hexColor
    }

    private func createFont(dict: [String : String]) -> UIFont? {
        let name = dict["fontName"]
        let size = dict["fontSize"]

        guard name != nil && size != nil else {
            AirshipLogger.error("Font name must be a valid string under the key \"fontName\". Font size must be a valid string under the key \"fontSize\"")
            return nil
        }

        let sizeNum = CGFloat(Double(size!) ?? 0)

        guard sizeNum > 0 else {
            AirshipLogger.error("Font size must represent a double greater than 0")
            return nil
        }

        let font = UIFont(name: name!, size: sizeNum)

        guard font != nil else {
            AirshipLogger.error("Font must exist in app bundle")
            return nil;
        }

        return font
    }
}
