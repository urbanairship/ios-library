import Foundation

@testable
import AirshipCore

@objc(UATestRemoteDataAPIClient)
public class TestRemoteDataAPIClient : NSObject, RemoteDataAPIClientProtocol {
 
    @objc
    public var metdataCallback: ((Locale, String?) -> [AnyHashable : String])?
    
    @objc
    public var fetchCallback: ((Locale, String?, (@escaping (RemoteDataResponse?, Error?) -> Void)) -> Void)?
    
    @objc
    public var defaultCallback: ((String) -> Void)?

    
    public func fetchRemoteData(locale: Locale, lastModified: String?, completionHandler: @escaping (RemoteDataResponse?, Error?) -> Void) -> Disposable {
        if let callback = fetchCallback {
            callback(locale, lastModified, completionHandler)
        } else {
            defaultCallback?("fetchRemoteData")
        }
        
        return Disposable()
    }
    
    public func metadata(locale: Locale, lastModified: String?) -> [AnyHashable : Any] {
        return self.metdataCallback?(locale, lastModified) ?? [:]
    }
}
