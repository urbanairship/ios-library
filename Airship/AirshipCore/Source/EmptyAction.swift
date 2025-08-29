/* Copyright Airship and Contributors */

import Foundation

/// Action that produces an empty result.
public final class EmptyAction: AirshipAction {
    public func accepts(arguments: ActionArguments) async -> Bool {
        return true
    }

    public func perform(arguments: ActionArguments) async throws -> AirshipJSON? {
        return nil
    }
}
