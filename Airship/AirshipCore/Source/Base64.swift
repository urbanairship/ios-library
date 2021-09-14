/* Copyright Airship and Contributors */

/**
 * - Note: For internal use only. :nodoc:
 */
@objc(UABase64)
public class Base64 : NSObject {

    @objc
    public class func dataFromString(_ base64String: String) -> Data? {
        var normalizedString = base64String.components(separatedBy: CharacterSet.newlines).joined(separator: "")
        normalizedString = normalizedString.replacingOccurrences(of: "=", with: "")

        // Must be a multiple of 4 characters post padding
        // For more information: https://tools.ietf.org/html/rfc4648#section-8
        switch (normalizedString.count % 4) {
        case 2:
            normalizedString += "=="
        case 3:
            normalizedString += "="
        default:
            break
        }

        return Data(base64Encoded: normalizedString, options: .ignoreUnknownCharacters)
    }

    @objc
    public class func stringFromData(_ data: Data) -> String? {
        let base64 = data.base64EncodedData(options: .lineLength64Characters)
        return String(data: base64, encoding: .ascii)
    }
}
