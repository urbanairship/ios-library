/* Copyright Airship and Contributors */

@testable
import AirshipChat

class MockHTTPRequestSession: HTTPRequestSession {
    private (set) var lastRequest: URLRequest?

    var responseBody : String?
    var response : HTTPURLResponse?
    var error : Error?

    func performHTTPDataTask(_ request: URLRequest, completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        self.lastRequest = request
        completionHandler(self.responseBody?.data(using: .utf8), self.response, self.error)
    }
}
