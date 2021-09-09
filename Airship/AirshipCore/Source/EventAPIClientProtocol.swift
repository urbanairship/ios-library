/* Copyright Airship and Contributors */

import Foundation

/// EventAPIClientProtocol. For internal use only.
/// :nodoc:
@objc(UAEventAPIClientProtocol)
public protocol EventAPIClientProtocol {
    @objc
    @discardableResult
    func uploadEvents(_ events: [AnyHashable], headers: [String : String], completionHandler: @escaping (EventAPIResponse?, Error?) -> Void) -> Disposable
}
