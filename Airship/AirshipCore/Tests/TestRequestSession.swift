import Foundation
import AirshipCore

@objc(UATestRequestSession)
public class TestRequestSession : RequestSession {

    @objc
    public var lastRequest: Request?

    @objc
    public var response: HTTPURLResponse?

    @objc
    public var error: Error?

    @objc
    public var data: Data?

    @objc
    public init() {
        let config = RuntimeConfig(config: Config(), dataStore: PreferenceDataStore(keyPrefix: UUID().uuidString))
        super.init(config: config, session: RequestSession.sharedURLSession)
    }

    public override func performHTTPRequest(_ request: Request, completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) -> Disposable {
        self.lastRequest = request
        completionHandler(data, response, error)
        return Disposable()
    }

}
