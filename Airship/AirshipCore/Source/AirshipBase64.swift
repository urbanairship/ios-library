/* Copyright Airship and Contributors */

import Foundation

/// - Note: For internal use only. :nodoc:
public class AirshipBase64: NSObject {

    public class func data(from base64String: String) -> Data? {
        var normalizedString = base64String.components(separatedBy: .newlines)
            .joined(separator: "")
            .replacingOccurrences(
                of: "=",
                with: ""
            )

        // Must be a multiple of 4 characters post padding
        // For more information: https://tools.ietf.org/html/rfc4648#section-8
        switch normalizedString.count % 4 {
        case 2:
            normalizedString += "=="
        case 3:
            normalizedString += "="
        default:
            break
        }

        return Data(
            base64Encoded: normalizedString,
            options: .ignoreUnknownCharacters
        )
    }

    public class func string(from data: Data) -> String? {
        let base64 = data.base64EncodedData(options: .lineLength64Characters)
        return String(data: base64, encoding: .ascii)
    }
}
