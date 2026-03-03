/* Copyright Airship and Contributors */

import Foundation
import os

/// Default log handler. Logs to either os.Logger or just prints depending on OS version.
@_spi(AirshipInternal)
public final class DefaultLogHandler: AirshipLogHandler {
    private let privacyLevel: AirshipLogPrivacyLevel

    public init(privacyLevel: AirshipLogPrivacyLevel) {
        self.privacyLevel = privacyLevel
    }

    private static let logger: Logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "Airship"
    )

    public func log(
        logLevel: AirshipLogLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    ) {
        let logMessage = "[\(logLevel.icon)] [\(logLevel.initial)] \(fileID) \(function) [Line \(line)] \(message)"
        switch self.privacyLevel {
        case .private:
            DefaultLogHandler.logger.log(
                level: logLevel.logType,
                "\(logMessage, privacy: .private)"
            )
        case .public:
            DefaultLogHandler.logger.notice(
                "\(logMessage, privacy: .public)"
            )
        }
    }
}

extension AirshipLogLevel {
    fileprivate var initial: String {
        switch self {
        case .verbose: return "V"
        case .debug: return "D"
        case .info: return "I"
        case .warn: return "W"
        case .error: return "E"
        default: return "U"
        }
    }
    
    var icon: String {
        switch(self) {
        case .error: return "❌"
        case .warn: return "⚠️"
        case .info: return "🔹"
        case .debug: return "🛠️"
        case .verbose: return "📖"
        default: return ""
        }
    }

    fileprivate var logType: OSLogType {
        switch self {
        case .verbose: return OSLogType.debug
        case .debug: return OSLogType.debug
        case .info: return OSLogType.info
        case .warn: return OSLogType.default
        case .error: return OSLogType.error
        default: return OSLogType.default
        }
    }
}
