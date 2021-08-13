/* Copyright Airship and Contributors */

import Foundation
import QuartzCore

/**
 * Padding adds constant values to a view's top, bottom, trailing or leading
 * constraints within its parent view.
 */
@objc(UAPadding)
public class UAPadding : NSObject {

    /**
     * The spacing constant added between the top of a view and its parent's top.
     */
    @objc
    public var top: NSNumber?
    
    /**
     * The spacing constant added between the bottom of a view and its parent's bottom.
     */
    @objc
    public var bottom: NSNumber?
    
    /**
     * The spacing constant added between the leading edge of a view and its parent's leading edge.
     */
    @objc
    public var leading: NSNumber?
    
    /**
     * The spacing constant added between the trailing edge of a view and its parent's trailing edge.
     */
    @objc
    public var trailing: NSNumber?
    
    private static let UAPaddingTopKey = "top"
    private static let UAPaddingBottomKey = "bottom"
    private static let UAPaddingTrailingKey = "trailing"
    private static let UAPaddingLeadingKey = "leading"
    
    public init(_ top: NSNumber?, _ bottom: NSNumber?, _ leading: NSNumber?, _ trailing: NSNumber?) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
        super.init()
    }
    
    /**
     * Factory method to create a padding object.
     *
     * - Parameters:
     *   - top: The top padding.
     *   - bottom: The bottom padding.
     *   - leading: The leading padding.
     *   - trailing: The trailing padding.
     * - Returns: padding instance with specified padding.
     */
    @objc(paddingWithTop:bottom:leading:trailing:)
    public class func padding(_ top: NSNumber, _ bottom: NSNumber, _ leading: NSNumber, _ trailing: NSNumber) -> UAPadding {
        let padding = UAPadding(top, bottom, leading, trailing)
        return padding
    }
    
    /**
     * Factory method to create a padding object with a plist dictionary.
     *
     * - Parameters:
     *   - dictionary: The dictionary of keys and values to be parsed into a padding object.
     * - Returns: padding instance with specified padding.
     */
    @objc(paddingWithDictionary:)
    public class func padding(_ dictionary: NSDictionary?) -> UAPadding {
        guard let dictionary = dictionary else {
             return UAPadding(nil, nil, nil, nil)
        }
        
        let top = UAPadding.paddingValue(dictionary, UAPaddingTopKey)
        let bottom = UAPadding.paddingValue(dictionary, UAPaddingBottomKey)
        let leading = UAPadding.paddingValue(dictionary, UAPaddingLeadingKey)
        let trailing = UAPadding.paddingValue(dictionary, UAPaddingTrailingKey)
        
        return UAPadding(top, bottom, leading, trailing)
    }
    
    class func paddingValue(_ dict: NSDictionary, _ key: String) -> NSNumber? {
        guard let padding = dict[key] as? NSNumber else {
            return nil
        }
        
        return padding
    }
}
