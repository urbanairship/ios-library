/* Copyright Airship and Contributors */



#if canImport(AirshipCore)
import AirshipCore
#endif

/// Automation app state
public enum AutomationAppState: String, Sendable, Codable {
    /// App is in the foreground (active/inactive)
    case foreground

    /// App is in the background
    case background
}

/// Automation delay
public struct AutomationDelay: Sendable, Codable, Equatable {
    /// Number of seconds to delay the execution of the IAA
    var seconds: TimeInterval?

    /// Screen restrictions
    var screens: [String]?

    /// If a region ID restriction
    public var regionID: String?

    /// App state restriction
    public var appState: AutomationAppState?

    /// Cancellation triggers. These triggers only cancel the execution of the schedule not the entire schedule
    public var cancellationTriggers: [AutomationTrigger]?
    
    public var executionWindow: ExecutionWindow?

    enum CodingKeys: String, CodingKey {
        case seconds
        case screens = "screen"
        case regionID = "region"
        case appState = "app_state"
        case cancellationTriggers = "cancellation_triggers"
        case executionWindow = "execution_window"
    }
}
