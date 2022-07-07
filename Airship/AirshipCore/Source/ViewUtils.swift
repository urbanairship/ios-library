/* Copyright Airship and Contributors */

import UIKit

#if !os(watchOS)

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UAViewUtils)
public class ViewUtils : NSObject {
    @objc
    public class func applyContainerConstraints(toContainer container: UIView?, containedView contained: UIView?) {
        guard container != nil && contained != nil else {
            AirshipLogger.debug("Attempted to constrain a nil view")
            return
        }

        // This is a side effect, but these should be set to NO by default when using autolayout
        container?.translatesAutoresizingMaskIntoConstraints = false
        contained?.translatesAutoresizingMaskIntoConstraints = false

        var topConstraint: NSLayoutConstraint? = nil
        if let contained = contained {
            topConstraint = NSLayoutConstraint(
                item: contained,
                attribute: .top,
                relatedBy: .equal,
                toItem: container,
                attribute: .top,
                multiplier: 1.0,
                constant: 0.0)
        }

        // The container and contained are reversed here to allow positive constant increases to result in expected padding
        var bottomConstraint: NSLayoutConstraint? = nil
        if let container = container {
            bottomConstraint = NSLayoutConstraint(
                item: container,
                attribute: .bottom,
                relatedBy: .equal,
                toItem: contained,
                attribute: .bottom,
                multiplier: 1.0,
                constant: 0.0)
        }

        // The container and contained are reversed here to allow positive constant increases to result in expected padding
        var trailingConstraint: NSLayoutConstraint? = nil
        if let container = container {
            trailingConstraint = NSLayoutConstraint(
                item: container,
                attribute: .trailing,
                relatedBy: .equal,
                toItem: contained,
                attribute: .trailing,
                multiplier: 1.0,
                constant: 0.0)
        }

        var leadingConstraint: NSLayoutConstraint? = nil
        if let contained = contained {
            leadingConstraint = NSLayoutConstraint(
                item: contained,
                attribute: .leading,
                relatedBy: .equal,
                toItem: container,
                attribute: .leading,
                multiplier: 1.0,
                constant: 0.0)
        }

        topConstraint?.isActive = true
        bottomConstraint?.isActive = true
        trailingConstraint?.isActive = true
        leadingConstraint?.isActive = true
    }
}
#endif
