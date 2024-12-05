/* Copyright Airship and Contributors */

import Foundation
import os

/// Default log handler. Logs to either os.Logger or just prints depending on OS version.
final class DefaultLogHandler: AirshipLogHandler {
    @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
    private static let logger: Logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "",
        category: "Airship"
    )

    func log(
        logLevel: AirshipLogLevel,
        message: String,
        fileID: String,
        line: UInt,
        function: String
    ) {
        let logMessage = "[\(logLevel.initial)] \(fileID) \(function) [Line \(line)] \(message)"

        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            switch Airship.logPrivacyLevel {
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
        } else {
            print(logMessage)
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
