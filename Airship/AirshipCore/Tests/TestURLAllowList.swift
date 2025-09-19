/* Copyright Airship and Contributors */

public import AirshipCore

public final class TestURLAllowList: AirshipURLAllowList, @unchecked Sendable {
    public var delegate: (any URLAllowListDelegate)?

    public var onAllowURL: (@MainActor @Sendable (URL, URLAllowListScope) -> Bool)?

    public var isAllowedReturnValue: Bool = true
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
