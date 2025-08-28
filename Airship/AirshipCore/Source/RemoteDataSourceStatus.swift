/* Copyright Airship and Contributors */



/// NOTE: For internal use only. :nodoc:
public enum RemoteDataSourceStatus: Sendable {
    case upToDate
    case stale
    case outOfDate
}
