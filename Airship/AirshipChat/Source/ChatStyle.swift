/* Copyright Airship and Contributors */

import Foundation
import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Chat style.
 */
@objc(UAChatStyle)
public class ChatStyle : NSObject {
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
     * The outgoing text color.
     */
    @objc public var outgoingTextColor: UIColor?

    /**
     * The incoming text color.
     */
    @objc public var incomingTextColor: UIColor?

    /**
     * The message text font.
     */
    @objc public var messageTextFont: UIFont?

    /**
     * The outgoing chat bubble color.
     */
    @objc public var outgoingChatBubbleColor: UIColor?

    /**
     * The incoming chat bubble color.
     */
    @objc public var incomingChatBubbleColor: UIColor?

    /**
     * The date color.
     */
    @objc public var dateColor: UIColor?

    /**
     * The date font.
     */
    @objc public var dateFont: UIFont?

    /**
     * The background color.
     */
    @objc public var backgroundColor: UIColor?

    /**
     * The navigation bar color.
     */
    @objc public var navigationBarColor: UIColor?

    /**
     * The tint color.
     */
    @objc public var tintColor: UIColor?

    /**
     * Chat style initializer
     */
    public override init() {
        super.init()
    }

    /**
     * Chat style initializer for parsing from a plist.
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
                AirshipLogger.error("Error reading chat style plist: \(error)")
            }
        } else {
            AirshipLogger.error("Unable to find chat plist file: \(file)")
        }
    }

    public override func setValue(_ value: Any?, forUndefinedKey key: String) {
        // Do not crash on undefined keys
        AirshipLogger.debug("Ignoring invalid chat style key: \(key)")
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
        let hexColor = UAColorUtils.color(withHexString: string)
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
