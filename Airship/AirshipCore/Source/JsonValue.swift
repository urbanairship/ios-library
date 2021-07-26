/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
struct JsonValue : Codable {
    let jsonEncodedValue: String?
    
    func value() -> Any? {
        if let jsonEncodedValue = jsonEncodedValue {
            return JSONSerialization.object(with: jsonEncodedValue, options: .allowFragments)
        } else {
            return nil
        }
    }
    
    init(value: Any?) {
        if let value = value {
            self.jsonEncodedValue = JSONSerialization.string(with: value, acceptingFragments: true)
        } else {
            self.jsonEncodedValue = nil
        }
    }
}
