/* Copyright Airship and Contributors */

import CommonCrypto
import Foundation
import SwiftUI

#if !os(watchOS)
import SystemConfiguration
#endif

#if os(iOS) && !targetEnvironment(macCatalyst)
import CoreTelephony
#endif

/// Representations of various device connection types.
@objc(UAConnectionType)
public class ConnectionType: NSObject {
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
public class AirshipUtils: NSObject {

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
        let modelName = machineMirror.children.reduce(
            "",
            { modelName, element in
                guard let value = element.value as? Int8, value != 0 else {
                    return modelName
                }
                return modelName + String(UnicodeScalar(UInt8(value)))
            }
        )

        return modelName
        #endif
    }

    /// Gets the short bundle version string.
    ///
    /// - Returns: A short bundle version string value.
    @objc
    public class func bundleShortVersionString() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String
    }

    /// Gets the current carrier name.
    ///
    /// - Returns: The current carrier name.
    @objc
    public class func carrierName() -> String? {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let info = CTTelephonyNetworkInfo()
        return info.serviceSubscriberCellularProviders?.values.first?
            .carrierName
        #else
        return nil
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

        guard
            let reachability = withUnsafePointer(
                to: &zeroAddress,
                {
                    $0.withMemoryRebound(
                        to: sockaddr.self,
                        capacity: MemoryLayout<sockaddr>.size
                    ) { ptr in
                        SCNetworkReachabilityCreateWithAddress(nil, ptr)
                    }
                }
            )
        else {
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

        if flags.contains(.connectionOnDemand)
            || flags.contains(.connectionOnTraffic)
        {
            if !flags.contains(.interventionRequired) {
                connectionType = ConnectionType.wifi
            }
        }

        if flags.contains(.isWWAN) {
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
    public class func compareVersion(_ fromVersion: String, toVersion: String)
        -> ComparisonResult
    {
        let fromParts = fromVersion.components(separatedBy: ".")
            .map {
                ($0 as NSString).integerValue
            }
        let toParts = toVersion.components(separatedBy: ".")
            .map {
                ($0 as NSString).integerValue
            }

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


    // MARK: UI Utilities

    #if !os(watchOS)
    /// Returns the main window for the app.
    ///
    /// This window will be positioned underneath any other windows added and removed at runtime,
    /// by classes such a `UIAlertView` or `UIActionSheet`.
    ///
    /// - Returns: The main window, or `nil` if the window cannot be found.
    @MainActor
    public class func mainWindow() throws -> UIWindow? {
        let scene = try AirshipSceneManager.shared.lastActiveScene

        let sharedApp: UIApplication = UIApplication.shared
        for window in scene.windows {
            if window.isKeyWindow {
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
    @MainActor
    @available(iOS 13.0, tvOS 13.0, *)
    public class func mainWindow(scene: UIWindowScene) -> UIWindow? {
        for w in scene.windows {
            if !w.isHidden {
                return w
            }
        }

        return try? self.mainWindow()
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
    public class func mergeFetchResults(
        _ results: [UInt]
    ) -> UIBackgroundFetchResult {
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
    public class func mergeFetchResults(_ results: [UInt])
        -> WKBackgroundFetchResult
    {
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
    public class func isSilentPush(_ notification: [AnyHashable: Any]) -> Bool {
        guard let apsDict = notification["aps"] as? [AnyHashable: Any] else {
            return true
        }

        if apsDict["badge"] != nil {
            return false
        }

        if let soundName = apsDict["sound"] as? String {
            if !soundName.isEmpty {
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
    public class func isAlertingPush(_ notification: [AnyHashable: Any]) -> Bool
    {
        guard let apsDict = notification["aps"] as? [AnyHashable: Any] else {
            return false
        }

        if let alert = apsDict["alert"] as? [AnyHashable: Any] {
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
    public class func deviceTokenStringFromDeviceToken(_ token: Data) -> String
    {
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
    public class func authHeader(username: String, password: String) -> String?
    {
        guard let data = "\(username):\(password)".data(using: .utf8) else {
            return nil
        }
        guard let encodedData = AirshipBase64.string(from: data) else {
            return nil
        }
        let authString =
            encodedData
            //strip carriage return and linefeed characters
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        return "Basic \(authString)"
    }

   
    // MARK: URL

    /// Parse url for the input string.
    ///
    /// - Parameter value: Input string for which to create the URL.
    ///
    /// - Returns: returns the created URL otherwise return nil.
    @objc(parseURL:)
    public class func parseURL(_ value: String) -> URL? {
        if let url = URL(string: value) {
            return url
        }

        /* Characters reserved for url  */
        let reserved = "!*'();:@&=+$,/?%#[]"
        /* Characters are not reserved for url but should not be encoded */
        let unreserved = ":-._~/? "
        let allowed = NSMutableCharacterSet.alphanumeric()
        allowed.addCharacters(in: reserved)
        allowed.addCharacters(in: unreserved)
        if let encoded = value.addingPercentEncoding(
            withAllowedCharacters: allowed as CharacterSet
        ) {
            return URL(string: encoded)

        }
        return nil
    }

    class func generateSignedToken(secret: String, tokenParams: [String]) throws -> String {
        let secret = NSData(data: Data(secret.utf8))
        let message = NSData(data: Data(tokenParams.joined(separator: ":").utf8))

        let hash = NSMutableData(length: Int(CC_SHA256_DIGEST_LENGTH))
        guard let hash else {
            throw AirshipErrors.error("Failed to generate signed token")
        }

        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), secret.bytes, secret.count, message.bytes, message.count, hash.mutableBytes)

        return hash.base64EncodedString(options: [])
    }
}

extension Locale {
    func getLanguageCode() -> String {
        let localeLanguage: String

        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            localeLanguage = self.language.languageCode?.identifier ?? ""
        } else {
            localeLanguage = self.languageCode ?? ""
        }

        return localeLanguage
    }

    func getRegionCode() -> String {
        let localeRegion: String

        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            localeRegion = self.region?.identifier ?? ""
        } else {
            localeRegion = self.regionCode ?? ""
        }

        return localeRegion
    }

    func getVariantCode() -> String {
        let variantCode: String

        if #available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *) {
            variantCode = self.variant?.identifier ?? ""
        } else {
            variantCode = self.variantCode ?? ""
        }

        return variantCode
    }
}
