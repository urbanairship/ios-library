/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockWebSocket: WebSocketProtocol {
    var isOpen = false
    var lastMessage : String?
    var sendError : Error?
    var delegate: WebSocketDelegate?

    func open() {
        self.isOpen = true
    }

    func close() {
        self.isOpen = false
    }

    func send(_ message: String, completionHandler: @escaping (Error?) -> ()) {
        self.lastMessage = message
        completionHandler(self.sendError)
    }

    var isOpenOrOpening: Bool {
        return isOpen
    }
}
