/* Copyright Airship and Contributors */

/**
 * Event to track install attributions.
 */
@objc(UAInstallAttributionEvent)
public class InstallAttributionEvent : NSObject, Event {
    @objc
    public var eventType : String {
        get {
            return "install_attribution"
        }
    }

    private let _data : [AnyHashable : Any]

    @objc
    public  var data: [AnyHashable : Any] {
        get {
            return self._data
        }
    }

    @objc
    public var priority: EventPriority {
        get {
            return .normal
        }
    }

    @objc
    public override init() {
        self._data = [:]
        super.init()
    }

    @objc
    public init(appPurchaseDate: Date, iAdImpressionDate: Date) {
        var data: [AnyHashable : Any] = [:]
        data["app_store_purchase_date"] = "\(appPurchaseDate.timeIntervalSince1970)"
        data["app_store_ad_impression_date"] = "\(iAdImpressionDate.timeIntervalSince1970)"

        self._data = data
        super.init()
    }

    /**
     * Factory method to create a InstallAttributionEvent.
     * - Parameter appPurchaseDate: The app purchase date.
     * - Parameter iAdImpressionDate: The iAD impression date.
     * - Returns: InstallAttributionEvent instance.
     */
    @objc(eventWithAppPurchaseDate:iAdImpressionDate:)
    public class func event(appPurchaseDate: Date, iAdImpressionDate: Date) -> InstallAttributionEvent {
        return InstallAttributionEvent(appPurchaseDate: appPurchaseDate, iAdImpressionDate: iAdImpressionDate)
    }

    /**
     * Factory method to create an InstallAttributionEvent.
     * - Returns: InstallAttributionEvent instance.
     */
    @objc
    public class func event() -> InstallAttributionEvent {
        return InstallAttributionEvent()
    }

}
