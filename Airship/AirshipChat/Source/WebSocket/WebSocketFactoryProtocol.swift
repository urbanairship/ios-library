/* Copyright Airship and Contributors */

import Foundation

/**
 * Web socket factory protocol.
 */
protocol WebSocketFactoryProtocol {

    /**
     * Creates a web socket for the given URL.
     * @param url The URL.
     * @returns A web socket.
     */
    func createWebSocket(url: URL) -> WebSocketProtocol
}
