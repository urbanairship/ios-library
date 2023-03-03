/* Copyright Airship and Contributors */

import Foundation
import os

/// Default log handler. Logs to either os.Logger or just prints depending on OS version.
class DefaultLogHandler: AirshipLogHandler {
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
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
            DefaultLogHandler.logger.log(
                level: logLevel.logType,
                "[\(logLevel.initial)] \(fileID) \(function) [Line \(line)] \(message)"
            )
        } else {
            print(
                "[\(logLevel.initial)] \(fileID) \(function) [Line \(line)] \(message)"
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
