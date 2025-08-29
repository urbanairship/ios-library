import Foundation

@testable public import AirshipCore

public class TestLocaleManager: AirshipLocaleManagerProtocol, @unchecked Sendable {

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
