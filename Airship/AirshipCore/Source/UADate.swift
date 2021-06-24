/* Copyright Airship and Contributors */

/**
 * @note For internal use only. :nodoc:
 */
@objc
open class UADate : NSObject {

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
