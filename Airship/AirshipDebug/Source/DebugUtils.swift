/* Copyright Airship and Contributors */

import UIKit

class DebugUtils: NSObject {

}

internal extension Double {
    func toPrettyDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"

        return dateFormatter.string(from: Date(timeIntervalSince1970:self))
    }
}

// MARK: Custom Event View Utils

extension UITextField {
    func applyCupertinoBorder(_ color:UIColor) {
        self.layer.borderWidth = 1.0
        self.layer.cornerRadius = 5
        self.layer.borderColor = color.cgColor
    }
}

extension UITextView {
    func applyCupertinoBorder(_ color:UIColor) {
        self.layer.borderWidth = 1.0
        self.layer.cornerRadius = 5
        self.layer.borderColor = color.cgColor
    }
}

extension Int {
    func segmentIndexToType() -> PropertyType {
        switch self {
        case 0:
            return .boolean
        case 1:
            return .number
        case 2:
            return .string
        case 3:
            return .json
        default:
            return .boolean
        }
    }
}

extension String {
    func prettyJSONFormat() -> String? {
        guard let strData = self.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: strData, options : .allowFragments) else { return nil }

        if (JSONSerialization.isValidJSONObject(obj)) {
            guard let data = try? JSONSerialization.data(withJSONObject:obj, options:.prettyPrinted) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    func JSONFormat() -> Any? {
        guard let strData = self.data(using: .utf8, allowLossyConversion: false) else { return nil }

        guard let obj = try? JSONSerialization.jsonObject(with: strData, options : .fragmentsAllowed) else { return nil }

        return obj
    }

    func isNumeric() -> Bool {
        let scanner = Scanner(string: self)

        scanner.locale = NSLocale.current

        return scanner.scanDecimal(nil) && scanner.isAtEnd
    }
}
