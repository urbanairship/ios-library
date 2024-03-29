/* Copyright Airship and Contributors */

/// - Note: for internal use only.  :nodoc:
public final class AirshipErrors: NSObject {
    public class func parseError(_ message: String) -> Error {
        return NSError(
            domain: "com.urbanairship.parse_error",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }

    public class func error(_ message: String) -> Error {
        return NSError(
            domain: "com.urbanairship.error",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }
}
