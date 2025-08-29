/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// NOTE: For internal use only. :nodoc:
public struct DeferredAutomationData: Sendable, Codable, Equatable {
    enum DeferredType: String, Codable, Sendable {
        case inAppMessage = "in_app_message"
        case actions
    }

    let url: URL
    let retryOnTimeOut: Bool?
    let type: DeferredType

    enum CodingKeys: String, CodingKey {
        case url
        case retryOnTimeOut = "retry_on_timeout"
        case type
    }
}
