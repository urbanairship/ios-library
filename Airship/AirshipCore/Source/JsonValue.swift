/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
struct JsonValue: Codable {
    let jsonEncodedValue: String?

    func value() -> Any? {
        guard let jsonEncodedValue = jsonEncodedValue else {
            return nil
        }
        return try? JSONUtils.object(jsonEncodedValue, options: .allowFragments)
    }

    init(value: Any?) {
        if let value = value {
            self.jsonEncodedValue = try? JSONUtils.string(
                value,
                options: .fragmentsAllowed
            )
        } else {
            self.jsonEncodedValue = nil
        }
    }
}
