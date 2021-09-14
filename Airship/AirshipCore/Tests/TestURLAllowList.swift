/* Copyright Airship and Contributors */

import AirshipCore

@objc(UATestURLAllowList)
public class TestURLAllowList : URLAllowList {
    
    @objc
    public var isAllowedReturnValue: Bool = true
    @objc
    public var addEntryReturnValue: Bool = true

    public override func isAllowed(_ url: URL?) -> Bool {
        return isAllowedReturnValue
    }

    public override func isAllowed(_ url: URL?, scope: URLAllowListScope) -> Bool {
        return isAllowedReturnValue
    }

    public override func addEntry(_ patternString: String) -> Bool {
        return addEntryReturnValue
    }

    public override func addEntry(_ patternString: String, scope: URLAllowListScope) -> Bool {
        return addEntryReturnValue
    }
}
