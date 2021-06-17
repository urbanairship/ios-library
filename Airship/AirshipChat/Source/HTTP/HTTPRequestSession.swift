/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif
protocol HTTPRequestSession {
    func performHTTPDataTask(_ request: URLRequest, completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void)
}

extension URLSession: HTTPRequestSession {
    func performHTTPDataTask(_ request: URLRequest, completionHandler: @escaping (Data?, HTTPURLResponse?, Error?) -> Void) {
        let task = self.dataTask(with: request) { (data, response, error) in
            guard (error == nil && response != nil) else {
                completionHandler(data, nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completionHandler(data, nil,  AirshipErrors.parseError("Bad response"))
                return
            }

            completionHandler(data, httpResponse, nil)
        }

        task.resume()
    }
}
