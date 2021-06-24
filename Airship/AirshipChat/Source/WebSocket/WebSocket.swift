/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Web socket implementation that uses NSURLSessionWebSocketTasks.
 */
@available(iOS 13.0, *)
class WebSocket : NSObject, WebSocketProtocol, URLSessionWebSocketDelegate {
    private let url : URL
    private let lock = Lock()
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
        lock.sync {
            guard !self.isOpenOrOpening else {
                return
            }

            var request = URLRequest(url: self.url)
            request.timeoutInterval = 5

            self.webSocketTask = self.urlSession.webSocketTask(with: request)
            self.webSocketTask?.resume()

            receive()
            schedulePing()
        }
    }

    func close() {
        lock.sync {
            if (self.webSocketTask != nil) {
                self.webSocketTask?.cancel(with: .goingAway, reason: nil)
                self.webSocketTask = nil
                self.delegate?.onClose()
            }
        }
    }

    func send(_ message: String, completionHandler: @escaping (Error?) -> ()) {
        lock.sync {
            let socketMessage = URLSessionWebSocketTask.Message.string(message)
            webSocketTask?.send(socketMessage, completionHandler: completionHandler)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        lock.sync {
            if  (self.webSocketTask == webSocketTask) {
                self.delegate?.onClose()
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        lock.sync {
            if  (self.webSocketTask == webSocketTask) {
                self.delegate?.onOpen()
            }
        }
    }

    private func receive() {
        let webSocketTask = self.webSocketTask
        webSocketTask?.receive { [weak self] result in
            self?.lock.sync {
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
            }

            self?.receive()
        }
    }

    private func schedulePing() {
        UADispatcher.main.dispatch(after: 30) { [weak self] in
            self?.webSocketTask?.sendPing(pongReceiveHandler: { (error) in
                self?.schedulePing()
            })
        }
    }
}

