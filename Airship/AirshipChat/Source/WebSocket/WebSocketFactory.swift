/* Copyright Airship and Contributors */

import Foundation

/**
 * Web socket factory.
 */
@available(iOS 13.0, *)
class WebSocketFactory: WebSocketFactoryProtocol {
    func createWebSocket(url: URL) -> WebSocketProtocol {
        return WebSocket(url: url)
    }
}
