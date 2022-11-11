import Foundation

@testable import AirshipCore

@objc(UATestLocaleManager)
public class TestLocaleManager: NSObject, LocaleManagerProtocol {

    public var _locale: Locale? = nil

    public func clearLocale() {
        self._locale = nil
    }

    public var currentLocale: Locale {
        get {
            return self._locale ?? Locale.autoupdatingCurrent
        }
        set {
            self._locale = newValue
        }
    }
}
