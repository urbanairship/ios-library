import Foundation

@testable
import AirshipCore

class TestChannelBulkUpdateAPIClient: ChannelBulkUpdateAPIClientProtocol {
    
    var updateCallback: ((String, AudienceUpdate, ((HTTPResponse?, Error?) -> Void)) -> Void)?
    var defaultCallback: ((String) -> Void)?
    
    init() {}
    
    func update(
        _ update: AudienceUpdate,
        channelID: String,
        completionHandler: @escaping (HTTPResponse?, Error?) -> Void
    ) -> Disposable {
        if let callback = updateCallback {
            callback(channelID, update, completionHandler)
        } else {
            defaultCallback?("update")
        }
        
        return Disposable()
    }
}
