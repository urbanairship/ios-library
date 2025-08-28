/* Copyright Airship and Contributors */



/// InApp automation status. Possible values are upToDate, stale and outOfDate.
public enum InAppAutomationUpdateStatus: Sendable {
    case upToDate
    case stale
    case outOfDate
}

