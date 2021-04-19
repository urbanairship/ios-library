/* Copyright Airship and Contributors */

import Foundation

/**
 * Web socket delegate.
 */
protocol WebSocketDelegate: AnyObject {
    /**
     * Called when the socket is opened.
     */
    func onOpen()

    /**
     * Called when the socket is closed.
     */
    func onClose()

    /**
     * Called when the socket recieved an error.
     */
    func onError(error: Error)

    /**
     * Called when the socket received a message.
     */
    func onReceive(message: String)
}


/**
 * Web socket protocol.
 */
protocol WebSocketProtocol: AnyObject {
    /**
     * Opens the socket.
     */
    func open()

    /**
     * Closes the socket.
     */
    func close()

    /**
     * Sends a message to the socket.
     * @param message The message.
     * @param completinonHandler The completion handler
     */
    func send(_ message: String, completionHandler: @escaping (Error?) -> ())

    /**
     *  Socket delegate.
     */
    var delegate: WebSocketDelegate? { get set }

    /**
     * Flag indicating the socket is open or in the process to open.
     * A `true` value means its safe to start sending messages.
     * @return `true` if the socket is open or opening, otherwise `false`.
     */
    var isOpenOrOpening: Bool { get }
}
