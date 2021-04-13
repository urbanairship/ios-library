/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0, *)
class ChatConnection : ChatConnectionProtocol, WebSocketDelegate  {
    private let chatConfig: ChatConfig!
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

    init(chatConfig: ChatConfig, socketFactory: WebSocketFactoryProtocol = WebSocketFactory()) {
        self.chatConfig = chatConfig
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

        guard let url = createURL(uvp: uvp) else {
            return
        }

        self.uvp = uvp
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
        let payload = SendMessageRequestPayload(requestID: requestID, text: text)
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

    private func createURL(uvp: String) -> URL? {
        guard let chatWebSocketURL = chatConfig.chatWebSocketURL else {
            AirshipLogger.error("Missing chat web socket URL")
            return nil;
        }

        let urlString = chatWebSocketURL + "?uvp=\(uvp)"
        guard let url = URL(string: urlString) else {
            AirshipLogger.error("Invalid URL: \(urlString)")
            return nil;
        }

        return url;
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
        let payload: SendMessageRequestPayload

        enum CodingKeys: String, CodingKey {
            case action = "action"
            case uvp = "uvp"
            case payload = "payload"
        }
    }

    private struct SendMessageRequestPayload : Encodable {
        let requestID: String
        let text: String

        enum CodingKeys: String, CodingKey {
            case text = "text"
            case requestID = "request_id"
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

