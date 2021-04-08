/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#elseif !COCOAPODS && canImport(Airship)
import Airship
#endif

/**
 * Web socket implementation that uses NSURLSessionWebSocketTasks.
 */
@available(iOS 13.0, *)
class WebSocket : NSObject, WebSocketProtocol, URLSessionWebSocketDelegate {
    private let url : URL
    private let lock = NSRecursiveLock()
    private lazy var urlSession: URLSession = URLSession(configuration: .default,
                                                         delegate: self,
                                                         delegateQueue: nil)

    private var webSocketTask : URLSessionWebSocketTask?


    var delegate: WebSocketDelegate?

    var isOpenOrOpening: Bool {
        get {
            return webSocketTask != nil
        }
    }

    init(url: URL) {
        self.url = url
        super.init()
    }

    func open() {
        lock.lock()
        guard !self.isOpenOrOpening else {
            lock.unlock()
            return
        }

        var request = URLRequest(url: self.url)
        request.timeoutInterval = 5

        self.webSocketTask = self.urlSession.webSocketTask(with: request)
        self.webSocketTask?.resume()
        lock.unlock()

        receive()
        schedulePing()
    }

    func close() {
        lock.lock()
        if (self.webSocketTask != nil) {
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            self.delegate?.onClose()
        }
        lock.unlock()
    }

    func send(_ message: String, completionHandler: @escaping (Error?) -> ()) {
        lock.lock()
        let socketMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(socketMessage, completionHandler: completionHandler)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.lock.lock()
        if  (self.webSocketTask == webSocketTask) {
            self.delegate?.onClose()
        }
        self.lock.unlock()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.lock.lock()
        if  (self.webSocketTask == webSocketTask) {
            self.delegate?.onOpen()
        }
        self.lock.unlock()
    }

    private func receive() {
        let webSocketTask = self.webSocketTask
        webSocketTask?.receive { [weak self] result in
            self?.lock.lock()

            guard self?.webSocketTask == webSocketTask else {
                return
            }

            switch result {
            case .failure(let error):
                self?.delegate?.onError(error: error)
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.delegate?.onReceive(message: text)
                default:
                    AirshipLogger.error("Unexpected result: \(result)")
                }
            }

            self?.lock.unlock()
            self?.receive()
        }
    }

    private func schedulePing() {
        UADispatcher.main().dispatch(after: 30) { [weak self] in
            self?.webSocketTask?.sendPing(pongReceiveHandler: { (error) in
                self?.schedulePing()
            })
        }
    }
}
