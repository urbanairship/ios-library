/* Copyright Airship and Contributors */

import Foundation
import CommonCrypto

#if !os(watchOS)
import SystemConfiguration
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreTelephony
#endif

/// Representations of various device connection types.
@objc(UAConnectionType)
public class ConnectionType : NSObject {
    /// Network is unreachable.
    @objc
    public static let none = "none"
    /// Network is a cellular or mobile network.
    @objc
    public static let cell = "cell"
    /// Network is a WiFi network.
    @objc
    public static let wifi = "wifi"
}

/// The `Utils` object provides an interface for utility methods.
@objc(UAUtils)
public class Utils : NSObject {
        
    // MARK: Math Utilities
    
    /// Compares two `float` values and returns `true` if the difference between them is less than or equal
    /// to the absolute value of the specified `accuracy`.
    ///
    /// - Parameters:
    ///   - float1: The first `float`.
    ///   - float2: The second `float`.
    ///   - accuracy: The maximum allowed difference between values to be compared as equal.
    ///
    /// - Returns: `true` if the difference between the two floats is within the given `accuracy`, `false` otherwise.
    @objc(float:isEqualToFloat:withAccuracy:)
    public class func isApproximatelyEqual(float1: CGFloat, float2: CGFloat, accuracy: CGFloat) -> Bool {
        if float1 == float2 {
            return true
        }
        
        let diff = abs(float1 - float2)
        return diff <= abs(accuracy)
    }
        
    // MARK: Device Utilities
    
    /// Get the device model name (e.g.,` iPhone3,1`).
    ///
    /// - Returns: The device model name.
    @objc
    public class func deviceModelName() -> String? {
        #if targetEnvironment(macCatalyst)
        return "mac"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let modelName = machineMirror.children.reduce("", { modelName, element in
            guard let value = element.value as? Int8, value != 0 else {
                return modelName
            }
            return modelName + String(UnicodeScalar(UInt8(value)))
        })
        
        return modelName
        #endif
    }
    
    /// Gets the short bundle version string.
    ///
    /// - Returns: A short bundle version string value.
    @objc
    public class func bundleShortVersionString() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    /// Gets the current carrier name.
    ///
    /// - Returns: The current carrier name.
    @objc
    public class func carrierName() -> String? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
            let info = CTTelephonyNetworkInfo()
            return info.subscriberCellularProvider?.carrierName
        #else
            return nil;
        #endif
    }
    
    #if !os(watchOS)
    /// Gets the current connection type.
    ///
    /// - Returns: The current connection type as a `String`.
    @objc
    public class func connectionType() -> String {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) { ptr in
                SCNetworkReachabilityCreateWithAddress(nil, ptr)
            }
        }) else {
            return ConnectionType.none
        }
        
        var flags = SCNetworkReachabilityFlags()
        let isSuccess = SCNetworkReachabilityGetFlags(reachability, &flags)
        
        var connectionType: String = ConnectionType.none
        
        guard isSuccess && flags.contains(.reachable) else {
            return ConnectionType.none
        }
        
        if !flags.contains(.connectionRequired) {
            connectionType = ConnectionType.wifi
        }
        
        if flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) {
            if !flags.contains(.interventionRequired) {
                connectionType = ConnectionType.wifi
            }
        }
        
        if (flags.contains(.isWWAN)) {
            connectionType = ConnectionType.cell
        }
        
        return connectionType
    }
    #endif

    /// Compares two version strings and determines their order.
    ///
    /// - Parameters:
    ///   - fromVersion: The first version.
    ///   - toVersion: The second version.
    ///
    /// - Returns: a `ComparisonResult`.
    @objc(compareVersion:toVersion:)
    public class func compareVersion(_ fromVersion: String, toVersion: String) -> ComparisonResult {
        let fromParts = fromVersion.components(separatedBy: ".").map { ($0 as NSString).integerValue }
        let toParts = toVersion.components(separatedBy: ".").map { ($0 as NSString).integerValue }

        var i = 0
        while fromParts.count > i || toParts.count > i {
            let from: Int = fromParts.count > i ? fromParts[i] : 0
            let to: Int = toParts.count > i ? toParts[i] : 0
            
            if from < to {
                return .orderedAscending
            } else if from > to {
                return .orderedDescending
            }
            i += 1
        }
        
        return .orderedSame
    }
    
    // MARK: Date Formatting
    
    /// Creates an ISO dateFormatter (UTC).
    ///
    /// The Formatter is created with the following attributes:
    /// - `locale` set to `en_US_POSIX`
    /// - `timestyle` set to `NSDateFormatterFullStyle`
    /// - `dateFormat` set to `yyyy-MM-dd HH:mm:ss`
    ///
    /// - Returns: A DateFormatter with the default attributes.
    @objc
    public class func ISODateFormatterUTC() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.init(identifier: "en_US_POSIX")
        formatter.timeStyle = .full
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.init(secondsFromGMT: 0)
        return formatter
    }
    
    /// Creates an ISO dateFormatter (UTC).
    ///
    /// The Formatter is created with the following attributes:
    /// - `locale` set to `en_US_POSIX`
    /// - `timestyle` set to `NSDateFormatterFullStyle`
    /// - `dateFormat` set to `yyyy-MM-dd'T'HH:mm:ss`.
    ///
    /// The formatter returned by this method is identical to that of `ISODateFormatterUTC`, except that the format matches
    /// the optional `T` delimiter between date and time.
    ///
    /// - Returns: A DateFormatter with the default attributes, matching the optional `T` delimiter.
    @objc(ISODateFormatterUTCWithDelimiter)
    public class func isoDateFormatterUTCWithDelimiter() -> DateFormatter {
        let formatter = ISODateFormatterUTC()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }
    
    /// Parses ISO 8601 date strings.
    ///
    /// Supports timestamps with just year all the way up to seconds with and without the optional `T` delimeter.
    ///
    /// - Parameter from: The ISO 8601 timestamp.
    ///
    /// - Returns: A parsed NSDate object, or nil if the timestamp is not a valid format.
    @objc(parseISO8601DateFromString:)
    public class func parseISO8601Date(from: String) -> Date? {
        return AirshipDateFormatter.date(fromISOString: from)
    }
    
    // MARK: UI Utilities
    
    #if !os(watchOS)
    /// Returns the main window for the app.
    ///
    /// This window will be positioned underneath any other windows added and removed at runtime,
    /// by classes such a `UIAlertView` or `UIActionSheet`.
    ///
    /// - Returns: The main window, or `nil` if the window cannot be found.
    @objc
    public class func mainWindow() -> UIWindow? {
        let sharedApp: UIApplication = UIApplication.shared
        for window in sharedApp.windows {
            if (window.isKeyWindow) {
                return window
            }
        }
        return sharedApp.delegate?.window ?? nil
    }
  
    /// Returns the main window for the given `UIWindowScene`.
    ///
    /// This window will be positioned underneath any other windows added and removed at runtime,
    /// by classes such a `UIAlertView` or `UIActionSheet`.
    ///
    /// - Parameter scene: The `UIWindowScene`.
    ///
    /// - Returns: The main window, or `nil` if the window cannot be found.
    @objc(mainWindow:)
    @available(iOS 13.0, tvOS 13.0, *)
    public class func mainWindow(scene: UIWindowScene) -> UIWindow? {
        for w in scene.windows {
            if !w.isHidden {
                return w
            }
        }

        return self.mainWindow()
    }
    
    /// Returns the window containing the provided view.
    ///
    /// - Parameter view: The view.
    ///
    /// - Returns: The window containing the view, or `nil` if the view is not currently displayed.
    @objc
    public class func windowFor(view: UIView) -> UIWindow? {
        var view: UIView? = view
        var window: UIWindow? = nil
        
        repeat {
            view = view?.superview
            if (view is UIWindow) {
                window = view as? UIWindow
            }
        } while (view != nil)
        
        return window
    }
    
    /// Returns the top-most view controller for the main application window, if found.
    ///
    /// - Returns: The top-most view controller or `nil` if a suitable view controller cannot be found.
    @objc
    @available(tvOSApplicationExtension, unavailable, message: "Method not available in app extensions")
    public class func topController() -> UIViewController? {
        var topController = self.mainWindow()?.rootViewController
        if topController == nil {
            AirshipLogger.debug("Unable to find top controller")
            return nil
        }
        
        // Iterate through any presented view controllers and find the top-most presentation context
        while topController?.presentedViewController != nil {
            topController = topController?.presentedViewController
        }
        
        return topController
    }
    
    @objc (presentInNewWindow:)
    public class func presentInNewWindow(_ rootViewController: UIViewController) -> UIWindow? {
        let window = createWindow()
        if #available(iOS 13.0, tvOS 13.0, *) {
            do {
                let scene = try findScene()
                window.windowScene = scene
            } catch {
                AirshipLogger.error("\(error)")
                return nil
            }
        }
        showWindow(window)
        window.rootViewController = rootViewController
        return window
    }
    
    private class func createWindow() -> UIWindow {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.windowLevel = .alert
        return window
    }
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    private class func findScene() throws -> UIWindowScene? {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.isKind(of: UIWindowScene.self) }) as? UIWindowScene else {
            throw AirshipErrors.error("Unable to find a window!")
        }
        return scene
    }
    
    private class func showWindow(_ window: UIWindow) {
        window.makeKeyAndVisible()
    }
    #endif
    
    
    // MARK: Fetch Results
    
    
    #if !os(watchOS)
    ///  Takes an array of fetch results and returns the merged result.
    ///
    /// - Parameter results: An `Array` of fetch results.
    ///
    /// - Returns: The merged fetch result.
    @objc
    public class func mergeFetchResults(_ results: [UInt]) -> UIBackgroundFetchResult {
        var mergedResult: UIBackgroundFetchResult = .noData
        for r in results {
            if r == UIBackgroundFetchResult.newData.rawValue {
                return .newData
            } else if r == UIBackgroundFetchResult.failed.rawValue {
                mergedResult = .failed
            }
        }
        return mergedResult
    }
    #else
    ///  Takes an array of fetch results and returns the merged result.
    ///
    /// - Parameter results: An `Array` of fetch results.
    ///
    /// - Returns: The merged fetch result.
    @objc
    public class func mergeFetchResults(_ results: [UInt]) -> WKBackgroundFetchResult {
        var mergedResult: WKBackgroundFetchResult = .noData
        for r in results {
            if r == WKBackgroundFetchResult.newData.rawValue {
                return .newData
            } else if r == WKBackgroundFetchResult.failed.rawValue {
                mergedResult = .failed
            }
        }
        return mergedResult
    }
    #endif
    
    // MARK: Notification Payload
    
    /// Determine if the notification payload is a silent push (no notification elements).
    ///
    /// - Parameter notification The notification payload.
    ///
    /// - Returns: `true` the notification is a silent push, `false` otherwise.
    @objc
    public class func isSilentPush(_ notification: [AnyHashable : Any]) -> Bool {
        guard let apsDict = notification["aps"] as? [AnyHashable : Any] else {
            return true
        }
        
        if apsDict["badge"] != nil {
            return false
        }
        
        if let soundName = apsDict["sound"] as? String {
            if (!soundName.isEmpty) {
                return false
            }
        }
        
        if isAlertingPush(notification) {
            return false
        }
        
        return true
    }
    
    /// Determine if the notification payload is an alerting push.
    ///
    /// - Parameter notification The notification payload.
    ///
    /// - Returns: `true` the notification is an alerting  push, `false` otherwise.
    @objc
    public class func isAlertingPush(_ notification: [AnyHashable : Any]) -> Bool {
        guard let apsDict = notification["aps"] as? [AnyHashable : Any] else {
            return false
        }
        
        if let alert = apsDict["alert"] as? [AnyHashable : Any] {
            if (alert["body"] as? String)?.isEmpty == false {
                return true
            }
            if (alert["loc-key"] as? String)?.isEmpty == false {
                return true
            }
        } else if let alert = apsDict["alert"] as? String {
            if !alert.isEmpty {
                return true
            }
        }
        
        return false
    }
    
    // MARK: Device Tokens
    
    /// Takes an APNS-provided device token and returns the decoded Airship device token.
    ///
    /// - Parameter token: An APNS-provided device token.
    ///
    /// - Returns: The decoded Airship device token.
    @objc
    public class func deviceTokenStringFromDeviceToken(_ token: Data) -> String {
        var tokenString = ""
        
        let bytes = [UInt8](token)
        for byte in bytes {
            tokenString = tokenString.appendingFormat("%02x", byte)
        }
        
        return tokenString.lowercased()
    }
    
    // MARK: SHA256 Utilities

    /// Generates a `SHA256` digest for the input string.
    ///
    /// - Parameter input: `String` for which to calculate SHA.
    /// - Returns: The `SHA256` digest as `NSData`.
    @objc(sha256DigestWithString:)
    public class func sha256Digest(input: String) -> NSData {
        guard let dataIn = input.data(using: .utf8) as NSData? else {
            return NSData()
        }
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: digestLength)
        CC_SHA256(dataIn.bytes, CC_LONG(dataIn.count), &digest)
        
        return NSData(bytes: digest, length: digestLength)
    }
    
    /// Generates a `SHA256` hash for the input string.
    ///
    /// - Parameter input: Input string for which to calculate SHA.
    ///
    /// - Returns: SHA256 digest as a hex string
    @objc(sha256HashWithString:)
    public class func sha256Hash(input: String) -> String {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        let digest = sha256Digest(input: input)
        var buffer = [UInt8](repeating: 0, count: digestLength)
        digest.getBytes(&buffer, length: digestLength)
        
        return buffer.map { String(format: "%02x", $0) }.joined(separator: "")
    }
    
    // MARK: UAHTTP Authenticated Request Helpers
    
    /// Returns a basic auth header string.
    ///
    /// - Parameters:
    ///   - username: The username.
    ///   - password: The password.
    /// - Returns: An HTTP Basic Auth header string value for the provided credentials in the form of: `Basic [Base64 Encoded "username:password"]`
    @objc(authHeaderStringWithName:password:)
    public class func authHeader(username: String, password: String) -> String? {
        guard let data = "\(username):\(password)".data(using: .utf8) else {
            return nil
        }
        guard let encodedData = Base64.stringFromData(data) else {
            return nil
        }
        let authString = encodedData
            //strip carriage return and linefeed characters
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        
        return "Basic \(authString)"
    }
    
    /// Logs a failed HTTP request.
    ///
    /// For internal use only. :nodoc:
    ///
    /// - Parameters:
    ///   - request: The request.
    ///   - message: The log message.
    ///   - error: The NSError.
    ///   - response: The HTTP response.
    @objc(logFailedRequest:withMessage:withError:withResponse:)
    public class func logFailedRequest(_ request: Request?, message: String?, error: NSError?, response: HTTPURLResponse?) {
        let logMessage = """
        ***** Request ERROR: \(message ?? "") *****
        \tError: \(String(describing: error?.description))
        Request:
        \tURL: \(String(describing: request?.url?.absoluteString))
        \tHeaders: \(String(describing: request?.headers))
        \tMethod: \(String(describing: request?.method))
        \tBody: \(String(describing: request?.body))
        Response:
        \tStatus code: \(String(describing: response?.statusCode))
        \tHeaders: \(String(describing: response?.allHeaderFields))
        \tBody: \(String(describing: response))
        """
        AirshipLogger.trace(logMessage)
    }
    
    // MARK: URL
    
    /// Parse url for the input string.
    ///
    /// - Parameter value: Input string for which to create the URL.
    ///
    /// - Returns: returns the created URL otherwise return nil.
    @objc(parseURL:)
    public class func parseURL(_ value:String) -> URL? {
        if let url = URL(string: value)  {
            return url
        }
        
        /* Caracters reserved for url  */
        let reserved = "!*'();:@&=+$,/?%#[]"
        /* Caracters are not reserved for url but should not be encoded */
        let unreserved = ":-._~/?"
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: reserved)
        allowed.addCharacters(in: unreserved)
        if let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed as CharacterSet) {
            return URL(string: encoded)
            
        }
        return nil
    }

    /// Needed to get stringValue in InAppAutomation. Delete after its converted to swift.
    /// - Note: For internal use only. :nodoc:
    @objc
    public class func permissionString(_ permission: Permission) -> String {
        return permission.stringValue
    }

    /// Needed to get stringValue in InAppAutomation. Delete after its converted to swift.
    /// - Note: For internal use only. :nodoc:
    @objc
    public class func permissionStatusString(_ status: PermissionStatus) -> String {
        return status.stringValue
    }

}
