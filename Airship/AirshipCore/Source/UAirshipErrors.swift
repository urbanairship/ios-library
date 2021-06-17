/* Copyright Airship and Contributors */

@objc(UAirshipErrors)
public class AirshipErrors : NSObject {
    @objc
    public class func parseError(_ message: String) -> Error {
        return NSError(domain: "com.urbanairship.parse_error", code: 1, userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }

    @objc
    public class func error(_ message: String) -> Error {
        return NSError(domain: "com.urbanairship.error", code: 1, userInfo: [
            NSLocalizedDescriptionKey: message
        ])
    }
}
