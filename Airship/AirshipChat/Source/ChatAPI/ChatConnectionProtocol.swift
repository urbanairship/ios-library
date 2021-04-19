/* Copyright Airship and Contributors */

import Foundation

/**
 * Chat connection delegate.
 */
protocol ChatConnectionDelegate : AnyObject {
    /**
     * Connection is opened.
     */
    func onOpen()

    /**
     * Received a chat response.
     * @param resposne The chat response.
     */
    func onChatResponse(_ response: ChatResponse)

    /**
     * Connection is closed.
     * @param reason Why the connection closed.
     */
    func onClose(_ reason: CloseReason)
}

/**
 * Close reasons.
 */
enum CloseReason {

    /**
     * A call to `close` was made.
     */
    case manual

    /**
     * Server terminated the connection.
     */
    case server

    /**
     * Closed due to an error.
     */
    case error
}

/**
 * Chat connection protocol.
 */
protocol ChatConnectionProtocol  {
    /**
     * If the connection is open or opening.
     */
    var isOpenOrOpening : Bool { get }

    /**
     * Delegate
     */
    var delegate: ChatConnectionDelegate? { get set }

    /**
     * Closes the connection.
     */
    func close()

    /**
     * Opens the connection with the given UVP.
     * @param uvp The UVP.
     */
    func open(uvp: String)

    /**
     * Requests the conversation.
     */
    func requestConversation()

    /**
     * Sends a message.
     * @param requestID The request ID.
     * @param text The message's text.
     * @param attachment The attachment.
     */
    func sendMessage(requestID: String, text: String?, attachment: URL?)
}

