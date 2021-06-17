/* Copyright Airship and Contributors */

#if canImport(AirshipCore)
import AirshipCore
#endif


protocol ChatConfig {
    var appKey: String { get }
    var chatURL: String? { get }
    var chatWebSocketURL: String? { get }
}

extension UARuntimeConfig : ChatConfig {}
