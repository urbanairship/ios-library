/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0, *)
class ChatConnection : ChatConnectionProtocol, WebSocketDelegate  {
    private static let socketURL : String = "wss://rb2socketscontactstest.replybuy.net?uvp="
    private var uvp: String?
    private var socket: WebSocketProtocol?
    private let lock = NSRecursiveLock()
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let socketFactory: WebSocketFactoryProtocol

    weak var delegate: ChatConnectionDelegate?
    var isOpenOrOpening : Bool {
        get {
            return socket?.isOpenOrOpening ?? false
        }
    }

    init(socketFactory: WebSocketFactoryProtocol = WebSocketFactory()) {
        self.socketFactory = socketFactory
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func close() {
        close(.manual)
    }

    private func close(_ reason: CloseReason) {
        self.lock.lock()

        if (self.isOpenOrOpening) {
            self.socket?.close()
            self.uvp = nil
            self.delegate?.onClose(reason)
        }

        self.lock.unlock()
    }

    func open(uvp: String) {
        self.lock.lock()

        guard !self.isOpenOrOpening else {
            self.lock.unlock()
            AirshipLogger.debug("ChatConnection already opened.")
            return
        }

        self.uvp = uvp

        guard let url = URL(string: ChatConnection.socketURL + uvp) else {
            AirshipLogger.error("Invalid URL: \(ChatConnection.socketURL + uvp)")
            return
        }

        self.socket = self.socketFactory.createWebSocket(url: url)
        self.socket?.delegate = self
        self.socket?.open()

        self.lock.unlock()
    }

    func requestConversation() {
        let requestConversation = FetchConversationRequest(uvp: self.uvp!)
        send(requestConversation)
    }

    func sendMessage(requestID: String, text: String) {
        let pendingMessage = PendingMessage(requestID: requestID, text: text)
        let sendMessagePayload = SendMessageRequestPayload(message: pendingMessage)

        guard let data = try? encoder.encode(sendMessagePayload) else {
            return
        }

        guard let payload = String(data:data, encoding: .utf8) else {
            return
        }

        let sendMessageRequest = SendMessageRequest(uvp: self.uvp!, payload: payload)
        send(sendMessageRequest)
    }

    private func send<T: Encodable>(_ value: T) {
        guard let data = try? self.encoder.encode(value) else {
            return
        }

        guard let jsonString = String(data:data, encoding: .utf8) else {
            return
        }

        self.socket?.send(jsonString) { (error) in
            if (error != nil) {
                AirshipLogger.error("Send error: \(error!)")
            } else {
                AirshipLogger.trace("Message sent \(jsonString)")
            }
        }
    }

    private struct FetchConversationRequest : Encodable {
        let action: String = "fetch_conversation"
        let uvp: String

        enum CodingKeys: String, CodingKey {
            case action = "action"
            case uvp = "uvp"
        }
    }

    private struct SendMessageRequest : Encodable {
        let action: String = "send_message"
        let uvp: String
        let payload: String

        enum CodingKeys: String, CodingKey {
            case action = "action"
            case uvp = "uvp"
            case payload = "payload"
        }
    }

    private struct PendingMessage : Encodable {
        let requestID: String
        let text: String

        enum CodingKeys: String, CodingKey {
            case text = "text"
            case requestID = "request_id"
        }
    }

    private struct SendMessageRequestPayload : Encodable {
        let message: PendingMessage

        enum CodingKeys: String, CodingKey {
            case message = "message"
        }
    }

    func onOpen() {
        AirshipLogger.trace("Connection opened")
        self.delegate?.onOpen()
    }

    func onClose() {
        AirshipLogger.trace("Connection closed")
        close(.server)
    }

    func onError(error: Error) {
        AirshipLogger.trace("Connection error: \(error)")
        close(.error)
    }

    func onReceive(message: String) {
        AirshipLogger.trace("Received message: \(message)")

        guard let data = message.data(using: .utf8) else {
            return
        }

        do {
            let response = try decoder.decode(ChatResponse.self, from: data)
            self.delegate?.onChatResponse(response)
        } catch {
            AirshipLogger.error("Error \(error) decoding response \(message)")
        }
    }
}

