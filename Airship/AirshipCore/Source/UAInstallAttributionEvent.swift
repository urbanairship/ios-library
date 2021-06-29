/* Copyright Airship and Contributors */

/**
 * Event to track install attributions.
 */
@objc
public class UAInstallAttributionEvent : UAEvent {

    @objc
    public override var eventType : String {
        get {
            return "install_attribution"
        }
    }

    private let _data : [AnyHashable : Any]

    @objc
    public override var data: [AnyHashable : Any] {
        get {
            return self._data
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
     * Factory method to create a UAInstallAttributionEvent.
     * @param appPurchaseDate The app purchase date.
     * @param iAdImpressionDate The iAD impression date.
     * @return UAInstallAttributionEvent instance.
     */
    @objc(eventWithAppPurchaseDate:iAdImpressionDate:)
    public class func event(appPurchaseDate: Date, iAdImpressionDate: Date) -> UAInstallAttributionEvent {
        return UAInstallAttributionEvent(appPurchaseDate: appPurchaseDate, iAdImpressionDate: iAdImpressionDate)
    }

    /**
     * Factory method to create a UAInstallAttributionEvent.
     * @return UAInstallAttributionEvent instance.
     */
    @objc
    public class func event() -> UAInstallAttributionEvent {
        return UAInstallAttributionEvent()
    }

}
