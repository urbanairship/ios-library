/* Copyright Airship and Contributors */

import Foundation

/**
 * @note For internal use only. :nodoc:
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
