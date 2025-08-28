/* Copyright Airship and Contributors */



/// Feature flag status. Possible values are upToDate, stale and outOfDate.
public enum FeatureFlagUpdateStatus: Sendable {
    case upToDate
    case stale
    case outOfDate
}
