/* Copyright Airship and Contributors */



/// Action result
public enum ActionResult: Sendable {
    /// Action ran and produced a result
    case completed(AirshipJSON)
    /// Action ran with an error
    case error(any Error)
    ///  Arguments rejected either by the action or predicate
    case argumentsRejected
    /// Action not found
    case actionNotFound
}
