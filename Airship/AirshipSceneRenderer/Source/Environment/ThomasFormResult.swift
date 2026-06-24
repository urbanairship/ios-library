/* Copyright Airship and Contributors */

import Foundation
public import AirshipBasement

/// - Note: For internal use only. :nodoc:
public struct ThomasFormResult: Sendable, Hashable, Equatable {
    public var identifier: String
    public var formData: AirshipJSON

    public init(identifier: String, formData: AirshipJSON) {
        self.identifier = identifier
        self.formData = formData
    }
}
