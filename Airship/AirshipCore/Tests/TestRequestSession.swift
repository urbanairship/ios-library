/* Copyright Airship and Contributors */

import AirshipCore
import Foundation

@objc(UATestRequestSession)
public class TestRequestSession: RequestSession {

    @objc
    public var previousRequest: Request?

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
        let config = RuntimeConfig(
            config: Config(),
            dataStore: PreferenceDataStore(appKey: UUID().uuidString)
        )
        super.init(config: config)
    }

    public override func performHTTPRequest(
        _ request: Request,
        completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void
    ) -> Disposable {
        self.previousRequest = self.lastRequest
        self.lastRequest = request
        completionHandler(data, response, error)
        return Disposable()
    }

}
