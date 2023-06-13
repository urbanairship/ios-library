/* Copyright Airship and Contributors */

import Foundation

/// Action result
public enum ActionResult: Sendable {
    /// Action ran and produced a result
    case completed(AirshipJSON)
    /// Action ran with an error
    case error(Error)
    ///  Arguments rejected either by the action or predicate
    case argumentsRejected
    /// Action not found
    case actionNotFound
}
