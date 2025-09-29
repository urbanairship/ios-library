/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

/// Example Airship SDK initialization handler.
///
/// This is a sample implementation showing how to configure and initialize
/// the Airship SDK with basic settings for development and production builds.
///
/// - Note: This is an example - customize for your app's needs.
struct AirshipInitializer {

    private init() {}
    
    /// Initializes Airship with example configuration.
    ///
    /// - Throws: An error if Airship initialization fails
    @MainActor
    static func initialize() throws {
        var config = try AirshipConfig.default()
        config.productionLogLevel = .verbose
        config.developmentLogLevel = .verbose

        #if DEBUG
        config.inProduction = false
        config.isAirshipDebugEnabled = true
        #else
        config.inProduction = true
        #endif

        try Airship.takeOff(config)
    }
}
