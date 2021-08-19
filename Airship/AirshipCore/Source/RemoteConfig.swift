/* Copyright Airship and Contributors */

// NOTE: For internal use only. :nodoc:
class RemoteConfig : NSObject, Codable {
    
    @objc
    public let remoteDataURL: String?
    
    @objc
    public let deviceAPIURL: String?
    
    @objc
    public let analyticsURL: String?
    
    @objc
    public let chatURL: String?
    
    @objc
    public let chatWebSocketURL: String?
    
    
    enum CodingKeys: String, CodingKey {
        case remoteDataURL = "remote_data_url"
        case deviceAPIURL = "device_api_url"
        case analyticsURL = "analytics_url"
        case chatURL = "chat_url"
        case chatWebSocketURL = "chat_web_socket_url"
    }
    
    init(remoteDataURL: String?,
         deviceAPIURL: String?,
         analyticsURL: String?,
         chatURL: String?,
         chatWebSocketURL: String?) {
        
        self.remoteDataURL = RemoteConfig.normalizeURL(remoteDataURL)
        self.deviceAPIURL = RemoteConfig.normalizeURL(deviceAPIURL)
        self.analyticsURL = RemoteConfig.normalizeURL(analyticsURL)
        self.chatURL = RemoteConfig.normalizeURL(chatURL)
        self.chatWebSocketURL = RemoteConfig.normalizeURL(chatWebSocketURL)
    }

    class func normalizeURL(_ urlString: String?) -> String? {
        guard var url = urlString,
              url.hasSuffix("/") else {
            return urlString
        }
        
        url.removeLast()
        return url
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let remoteConfig = object as? RemoteConfig else {
            return false
        }
        
        if (self === remoteConfig) {
            return true
        }
        
        return isEqual(to: remoteConfig)
    }

    func isEqual(to: RemoteConfig) -> Bool {
        guard self.deviceAPIURL == to.deviceAPIURL,
              self.analyticsURL == to.analyticsURL,
              self.remoteDataURL == to.remoteDataURL,
              self.chatURL == to.chatURL,
              self.chatWebSocketURL == to.chatWebSocketURL else {
            return false
        }
        
        return true
    }

    func hash() -> Int {
        var result = 1
        result = 31 * result + (deviceAPIURL?.hash ?? 0)
        result = 31 * result + (analyticsURL?.hash ?? 0)
        result = 31 * result + (remoteDataURL?.hash ?? 0)
        result = 31 * result + (chatURL?.hash ?? 0)
        result = 31 * result + (chatWebSocketURL?.hash ?? 0)
        return result
    }
}
