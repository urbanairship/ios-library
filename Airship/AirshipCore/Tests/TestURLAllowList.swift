/* Copyright Airship and Contributors */

import AirshipCore

public class TestURLAllowList: URLAllowListProtocol {

    @objc
    public var isAllowedReturnValue: Bool = true
    @objc
    public var addEntryReturnValue: Bool = true

    public func isAllowed(_ url: URL?) -> Bool {
        return isAllowedReturnValue
    }

    public func isAllowed(_ url: URL?, scope: URLAllowListScope)
        -> Bool
    {
        return isAllowedReturnValue
    }

    public func addEntry(_ patternString: String) -> Bool {
        return addEntryReturnValue
    }

    public func addEntry(
        _ patternString: String,
        scope: URLAllowListScope
    ) -> Bool {
        return addEntryReturnValue
    }
}
