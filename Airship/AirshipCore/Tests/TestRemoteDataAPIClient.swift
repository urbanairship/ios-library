import Foundation

@testable
import AirshipCore

@objc(UATestRemoteDataAPIClient)
public class TestRemoteDataAPIClient : NSObject, RemoteDataAPIClientProtocol {
 
    @objc
    public var metdataCallback: ((Locale) -> [AnyHashable : String])?
    
    @objc
    public var fetchCallback: ((Locale, String?, (@escaping (RemoteDataResponse?, Error?) -> Void)) -> Void)?
    
    @objc
    public var defaultCallback: ((String) -> Void)?

    
    public func fetchRemoteData(locale: Locale, lastModified: String?, completionHandler: @escaping (RemoteDataResponse?, Error?) -> Void) -> UADisposable {
        if let callback = fetchCallback {
            callback(locale, lastModified, completionHandler)
        } else {
            defaultCallback?("fetchRemoteData")
        }
        
        return UADisposable()
    }
    
    public func metadata(locale: Locale) -> [AnyHashable : Any] {
        return self.metdataCallback?(locale) ?? [:]
    }
}
