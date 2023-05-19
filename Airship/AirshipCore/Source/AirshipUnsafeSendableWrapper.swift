/* Copyright Airship and Contributors */

import Foundation

final class AirshipUnsafeSendableWrapper<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) {
        self.value = value
    }
}
