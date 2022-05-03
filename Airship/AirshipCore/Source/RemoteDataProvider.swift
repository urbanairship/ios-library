/* Copyright Airship and Contributors */

import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UARemoteDataProvider)
public protocol RemoteDataProvider {
    var remoteDataRefreshInterval: TimeInterval { get set }
    
    @discardableResult
    @objc
    func subscribe(types: [String], block:@escaping ([RemoteDataPayload]) -> Void) -> Disposable
    
    @objc
    func isMetadataCurrent(_ metadata: [AnyHashable : Any]) -> Bool
    
    @objc
    func refresh(completionHandler: @escaping (Bool) -> Void)
}
