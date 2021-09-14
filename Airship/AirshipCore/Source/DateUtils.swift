/* Copyright Airship and Contributors */

import Foundation

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UADate)
open class DateUtils : NSObject {

    @objc
    public override init() {
        super.init()
    }

    @objc
    open var now : Date {
        get {
            return Date()
        }
    }
}
