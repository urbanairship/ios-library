/* Copyright 2018 Urban Airship and Contributors */

import UIKit

class DebugKitUtils: NSObject {

}

internal extension Double {
    func toPrettyDateString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm:ss"

        return dateFormatter.string(from: Date(timeIntervalSince1970:self))
    }
}
