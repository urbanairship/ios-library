import Foundation
import AirshipCore

@objc(UATestRequestSession)
public class TestRequestSession : UARequestSession {

    @objc
    public var lastRequest: UARequest?

    @objc
    public var response: HTTPURLResponse?

    @objc
    public var error: Error?

    @objc
    public var data: Data?

    @objc
    public init() {
        super.init(config: UARuntimeConfig(), session: UARequestSession.sharedURLSession)
    }

    public override func performHTTPRequest(_ request: UARequest, completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> UADisposable {
        self.lastRequest = request
        completionHandler(data, response, error)
        return UADisposable()
    }

}
