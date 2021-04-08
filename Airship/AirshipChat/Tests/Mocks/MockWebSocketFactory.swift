/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockWebSocketFactory: WebSocketFactoryProtocol {

    private let socket: WebSocketProtocol
    var lastURL : URL?

    init(socket: WebSocketProtocol) {
        self.socket = socket
    }

    func createWebSocket(url: URL) -> WebSocketProtocol {
        self.lastURL = url
        return socket
    } 
}
