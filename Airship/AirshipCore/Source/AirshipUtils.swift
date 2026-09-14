/* Copyright Airship and Contributors */

import CommonCrypto
import Foundation

#if canImport(AirshipBasement)
@_spi(AirshipInternal) import AirshipBasement
#endif

#if !os(watchOS) && !os(macOS)
import UIKit
#endif


/// The `Utils` object provides an interface for utility methods.
@_spi(AirshipInternal)
public final class AirshipUtils {

    // MARK: Device Utilities

    /// Gets the short bundle version string.
    ///
    /// - Returns: A short bundle version string value.
    @_spi(AirshipInternal)
    public class func bundleShortVersionString() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"]
            as? String
    }

    /// Gets the bundle version string (build number / CFBundleVersion).
    ///
    /// - Returns: A bundle version string value.
    class func bundleBuildVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    /// Builds the iOS platform version object used for predicate matching in version triggers and audience checks.
    /// - Parameters:
    ///   - versionName: The marketing version (CFBundleShortVersionString).
    ///   - buildVersion: The build version (CFBundleVersion), if available.
    ///   - fromBuildVersion: The previous build version, if available.
    ///   - fromVersionName: The previous marketing version, if available.
    /// - Returns: An `AirshipJSON` value of the form `{ "ios": { ... } }`.
    @_spi(AirshipInternal)
    public class func createVersionObject(
        versionName: String,
        buildVersion: String? = nil,
        fromBuildVersion: String? = nil,
        fromVersionName: String? = nil
    ) -> AirshipJSON {
        var platformFields: [String: AirshipJSON] = [
            "version": .string(versionName),
            "version_name": .string(versionName)
        ]
        if let buildVersion { platformFields["build_version"] = .string(buildVersion) }
        if fromBuildVersion != nil || fromVersionName != nil {
            var fromFields: [String: AirshipJSON] = [:]
            if let fv = fromBuildVersion { fromFields["build_version"] = .string(fv) }
            if let fn = fromVersionName { fromFields["version_name"] = .string(fn) }
            platformFields["from"] = .object(fromFields)
        }
        return ["ios": .object(platformFields)]
    }

    // MARK: UI Utilities

    #if !os(watchOS) && !os(macOS)
    /// Returns the main window for the app.
    ///
    /// This window will be positioned underneath any other windows added and removed at runtime,
    /// by classes such a `UIAlertView` or `UIActionSheet`.
    ///
    /// - Returns: The main window, or `nil` if the window cannot be found.
    @MainActor
    class func mainWindow() throws -> UIWindow? {
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
    @MainActor
    class func mainWindow(scene: UIWindowScene) -> UIWindow? {
        for w in scene.windows {
            if !w.isHidden {
                return w
            }
        }

        return try? self.mainWindow()
    }


    #endif

    // MARK: Notification Payload

    /// Determine if the notification payload is a silent push (no notification elements).
    ///
    /// - Parameter notification The notification payload.
    ///
    /// - Returns: `true` the notification is a silent push, `false` otherwise.
    class func isSilentPush(_ notification: [AnyHashable: Any]) -> Bool {
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
    class func isAlertingPush(_ notification: [AnyHashable: Any]) -> Bool
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
            if (alert["title"] as? String)?.isEmpty == false {
                return true
            }
            if (alert["title-loc-key"] as? String)?.isEmpty == false {
                return true
            }
            if (alert["subtitle"] as? String)?.isEmpty == false {
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
    class func deviceTokenStringFromDeviceToken(_ token: Data) -> String
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
    class func sha256Digest(input: String) -> NSData {
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
    class func sha256Hash(input: String) -> String {
        let digestLength = Int(CC_SHA256_DIGEST_LENGTH)
        let digest = sha256Digest(input: input)
        var buffer = [UInt8](repeating: 0, count: digestLength)
        digest.getBytes(&buffer, length: digestLength)

        return buffer.map { String(format: "%02x", $0) }.joined(separator: "")
    }

    // MARK: URL

    /// Parse url for the input string.
    ///
    /// - Parameter value: Input string for which to create the URL.
    ///
    /// - Returns: returns the created URL otherwise return nil.
    class func parseURL(_ value: String) -> URL? {
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
        return self.language.languageCode?.identifier ?? ""
    }

    func getRegionCode() -> String {
        return self.region?.identifier ?? ""
    }

    func getVariantCode() -> String {
        return self.variant?.identifier ?? ""
    }
}

internal extension Int {
    func airshipLocalizedForVoiceOver() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

internal extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#if !os(watchOS) && !os(macOS)
internal extension UIWindowScene {
    /// The space actually available to this scene's windows.
    ///
    /// A scene does not necessarily fill its screen. On iPad, in iPhone Mirroring, and from
    /// iOS 27 on for any resizable app, it occupies an arbitrary slice of the display that the
    /// user can change at any time, so screen bounds do not describe what we are able to draw
    /// into. Prefer the scene's own resolved geometry, then its main window, and only fall back
    /// to the screen when neither has been laid out yet.
    @MainActor
    var airshipAvailableSpace: CGSize {
        if #available(iOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            let bounds = self.effectiveGeometry.coordinateSpace.bounds
            if !bounds.isEmpty {
                return bounds.size
            }
        }

        if let window = AirshipUtils.mainWindow(scene: self), !window.bounds.isEmpty {
            return window.bounds.size
        }

#if os(visionOS)
        // https://developer.apple.com/design/human-interface-guidelines/windows#visionOS
        return CGSize(width: 1280, height: 720)
#else
        return self.screen.bounds.size
#endif
    }
}
#endif
