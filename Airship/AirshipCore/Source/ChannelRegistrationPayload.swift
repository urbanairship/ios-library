import Foundation

// NOTE: For internal use only. :nodoc:
@objc(UAChannelRegistrationPayload)
public class ChannelRegistrationPayload : NSObject, Codable, NSCopying {
    
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    
    @objc(decode:error:)
    public class func decode(_ data: Data) throws -> ChannelRegistrationPayload {
        try decoder.decode(ChannelRegistrationPayload.self, from: data)
    }
    
    @objc(encodeWithError:)
    public func encode() throws -> Data {
        return try ChannelRegistrationPayload.encoder.encode(self)
    }
    
    @objc
    public let channel: ChannelInfo
    
    @objc
    public var identityHints: IdentityHints?
    
    enum CodingKeys: String, CodingKey {
        case channel = "channel"
        case identityHints = "identity_hints"
    }
    
    @objc
    public override init() {
        self.channel = ChannelInfo()
    }
    
    private init(_ payload: ChannelRegistrationPayload) {
        self.channel = ChannelInfo(payload.channel)
        self.identityHints = payload.identityHints?.copy() as! IdentityHints?
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        return ChannelRegistrationPayload(self)
    }
    
    @objc
    public func minimizePayload(previous: ChannelRegistrationPayload?) -> ChannelRegistrationPayload {
        let minPayload: ChannelRegistrationPayload = self.copy() as! ChannelRegistrationPayload
        
        guard let previous = previous else {
            return minPayload
        }
        
        let channel = minPayload.channel
        let previousChannel = previous.channel
        
        minPayload.identityHints = nil
        
        if (channel.setTags && previousChannel.setTags) {
            if (channel.tags == previousChannel.tags) {
                channel.tags = nil
                channel.setTags = false
            } else {
                let channelTags = channel.tags ?? []
                let previousTags = previousChannel.tags ?? []
                let adds = channelTags.filter { !previousTags.contains($0) }
                let removes = previousTags.filter { !channelTags.contains($0) }
                channel.tagChanges = TagChanges(adds: adds, removes: removes)
            }
        }
        
        if (channel.contactID == previousChannel.contactID) {
            if (channel.language == previousChannel.language) { channel.language = nil }
            if (channel.country == previousChannel.country) { channel.country = nil }
            if (channel.timeZone == previousChannel.timeZone) { channel.timeZone = nil }
            if (channel.appVersion == previousChannel.appVersion) { channel.appVersion = nil }
            if (channel.sdkVersion == previousChannel.sdkVersion) { channel.sdkVersion = nil }
            if (channel.isLocationEnabled == previousChannel.isLocationEnabled) { channel.isLocationEnabled = nil }
            if (channel.deviceModel == previousChannel.deviceModel) { channel.deviceModel = nil }
            if (channel.deviceOS == previousChannel.deviceOS) { channel.deviceOS = nil }
            if (channel.carrier == previousChannel.carrier) { channel.carrier = nil }
        }
        
        if let iOSChannelSetting = channel.iOSChannelSettings, let previousiOSChannelSetting = previous.channel.iOSChannelSettings {
            
            if (iOSChannelSetting.isScheduledSummary == previousiOSChannelSetting.isScheduledSummary) {
                iOSChannelSetting.isScheduledSummary = nil;
            }
            
            if(iOSChannelSetting.isTimeSensitive == previousiOSChannelSetting.isTimeSensitive){
                iOSChannelSetting.isTimeSensitive = nil;
            }
        }
        
        return minPayload
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? ChannelRegistrationPayload else {
            return false
        }
        
        return self == other
    }
    
    static func == (lh: ChannelRegistrationPayload, rh: ChannelRegistrationPayload) -> Bool {
        return lh.channel == rh.channel && lh.identityHints == rh.identityHints
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc(UAChannelInfo)
    public class ChannelInfo : NSObject, Codable, NSCopying {
        
        var deviceType = "ios"
        
        /// This flag indicates that the user is able to receive push notifications.
        @objc
        public var isOptedIn: Bool = false
        
        /// This flag indicates that the user is able to receive background notifications.
        @objc
        public var isBackgroundEnabled: Bool = false
        
        /// The address to push notifications to.  This should be the device token.
        @objc
        public var pushAddress: String?
        
        /// The flag indicates tags in this request should be handled.
        @objc
        public var setTags: Bool = false
        
        /// The tags for this device.
        @objc
        public var tags: [String]?
        
        /// Tag changes.
        @objc
        public var tagChanges: TagChanges?
       
        /// The locale language for this device.
        @objc
        public var language: String?
        
        /// The locale country for this device.
        @objc
        public var country: String?
        
        /// The time zone for this device.
        @objc
        public var timeZone: String?
        
        /// The location setting for the device.
        var isLocationEnabled: Bool?
        
        @objc
        /// The flag indicating if the user is active.
        public var isActive: Bool = false
        
        @objc
        public var locationEnabledNumber : NSNumber? {
            get {
                return isLocationEnabled as NSNumber?
            }
            set {
                isLocationEnabled = newValue?.boolValue
            }
        }
        
        /// The app version.
        @objc
        public var appVersion: String?
        
        /// The sdk version.
        @objc
        public var sdkVersion: String?
        
        /// The device model.
        @objc
        public var deviceModel: String?
        
        /// The device OS.
        @objc
        public var deviceOS: String?
        
        /// The carrier.
        @objc
        public var carrier: String?
        
        @objc
        public var contactID: String?
        
        @objc
        public var iOSChannelSettings: iOSChannelSettings?
        
        enum CodingKeys: String, CodingKey {
            case deviceType = "device_type"
            case isOptedIn = "opt_in"
            case isBackgroundEnabled = "background"
            case pushAddress = "push_address"
            case setTags = "set_tags"
            case tags = "tags"
            case tagChanges = "tag_changes"
            case language = "locale_language"
            case country = "locale_country"
            case timeZone = "timezone"
            case isLocationEnabled = "location_settings"
            case appVersion = "app_version"
            case sdkVersion = "sdk_version"
            case deviceModel = "device_model"
            case deviceOS = "device_os"
            case carrier = "carrier"
            case contactID = "contact_id"
            case iOSChannelSettings = "ios"
            case isActive = "is_activity"
        }
        
        override init() {
        }
        
        public func copy(with zone: NSZone? = nil) -> Any {
            return ChannelInfo(self)
        }
        
        init(_ payload: ChannelInfo) {
            self.deviceType = payload.deviceType
            self.isOptedIn = payload.isOptedIn
            self.isBackgroundEnabled = payload.isBackgroundEnabled
            self.pushAddress = payload.pushAddress
            self.setTags = payload.setTags
            self.tags = payload.tags
            self.tagChanges = payload.tagChanges
            self.language = payload.language
            self.country = payload.country
            self.timeZone = payload.timeZone
            self.isLocationEnabled = payload.isLocationEnabled
            self.appVersion = payload.appVersion
            self.sdkVersion = payload.sdkVersion
            self.deviceModel = payload.deviceModel
            self.deviceOS = payload.deviceOS
            self.carrier = payload.carrier
            self.contactID = payload.contactID
            self.iOSChannelSettings = payload.iOSChannelSettings?.copy() as! ChannelRegistrationPayload.iOSChannelSettings?
            self.isActive = payload.isActive
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? ChannelInfo else {
                return false
            }
            
            return self == other
        }
        
        static func == (lh: ChannelInfo, rh: ChannelInfo) -> Bool {
            return
                lh.deviceType == rh.deviceType &&
                lh.isOptedIn == rh.isOptedIn &&
                lh.isBackgroundEnabled == rh.isBackgroundEnabled &&
                lh.pushAddress == rh.pushAddress &&
                lh.setTags == rh.setTags &&
                lh.tags == rh.tags &&
                lh.tagChanges == rh.tagChanges &&
                lh.language == rh.language &&
                lh.country == rh.country &&
                lh.timeZone == rh.timeZone &&
                lh.isLocationEnabled == rh.isLocationEnabled &&
                lh.appVersion == rh.appVersion &&
                lh.sdkVersion == rh.sdkVersion &&
                lh.deviceModel == rh.deviceModel &&
                lh.deviceOS == rh.deviceOS &&
                lh.carrier == rh.carrier &&
                lh.contactID == rh.contactID &&
                lh.iOSChannelSettings == rh.iOSChannelSettings
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc(UATagChanges)
    public class TagChanges : NSObject, Codable {
        let adds: [String]?
        let removes: [String]?
        
        enum CodingKeys: String, CodingKey {
            case adds = "add"
            case removes = "remove"
        }
        
        init?(adds: [String], removes: [String]) {
            guard !adds.isEmpty || removes.isEmpty else {
                return nil
            }
            
            self.adds = adds.isEmpty ? nil : adds
            self.removes = removes.isEmpty ? nil : removes
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? TagChanges else {
                return false
            }
            
            return self == other
        }
        
        static func == (lh: TagChanges, rh: TagChanges) -> Bool {
            return lh.adds == rh.adds && lh.removes == rh.removes
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc(UAIOSChannelSettings)
    public class iOSChannelSettings : NSObject, Codable, NSCopying {
        /// Quiet time settings for this device.
        @objc
        public var quietTime: QuietTime?
        
        /// Quiet time time zone.
        @objc
        public var quietTimeTimeZone: String?
        
        /// The badge for this device.
        var badge: Int?
        
        @objc
        public var badgeNumber : NSNumber? {
            get {
                return badge as NSNumber?
            }
            set {
                badge = newValue?.intValue
            }
        }
        
        var isScheduledSummary: Bool?
        @objc
        public var scheduledSummary : NSNumber? {
            get {
                return isScheduledSummary as NSNumber?
            }
            set {
                isScheduledSummary = newValue?.boolValue
            }
        }
        
        var isTimeSensitive: Bool?
        @objc
        public var timeSensitive : NSNumber? {
            get {
                return isTimeSensitive as NSNumber?
            }
            set {
                isTimeSensitive = newValue?.boolValue
            }
        }
        
        
        @objc
        public override init() {}
        
        init(_ settings: iOSChannelSettings) {
            self.badge = settings.badge
            self.quietTime = settings.quietTime
            self.quietTimeTimeZone = settings.quietTimeTimeZone
            self.isScheduledSummary = settings.isScheduledSummary
            self.isTimeSensitive = settings.isTimeSensitive
        }
        
        public func copy(with zone: NSZone? = nil) -> Any {
            return iOSChannelSettings(self)
        }
        
        enum CodingKeys: String, CodingKey {
            case quietTime = "quiettime"
            case quietTimeTimeZone = "tz"
            case badge = "badge"
            case isScheduledSummary = "scheduled_summary"
            case isTimeSensitive = "time_sensitive"
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? iOSChannelSettings else {
                return false
            }
            
            return self == other
        }
        
        static func == (lh: iOSChannelSettings, rh: iOSChannelSettings) -> Bool {
            return
                lh.quietTime == rh.quietTime &&
                lh.quietTimeTimeZone == rh.quietTimeTimeZone &&
                lh.badge == rh.badge &&
                lh.isScheduledSummary == rh.isScheduledSummary &&
                lh.isTimeSensitive == rh.isTimeSensitive
        }
        
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc(UAIdentityHints)
    public class IdentityHints: NSObject, Codable, NSCopying {
        /// The user ID.
        @objc
        public var userID: String?
        
        /// The Accengage device ID.
        @objc
        public var accengageDeviceID: String?
        
        
        public override init() {
        }
        
        init(_ hints: IdentityHints) {
            self.userID = hints.userID
            self.accengageDeviceID = hints.accengageDeviceID
        }
        
        public func copy(with zone: NSZone? = nil) -> Any {
            return IdentityHints(self)
        }
        
        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case accengageDeviceID = "accengage_device_id"
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? IdentityHints else {
                return false
            }
            
            return self == other
        }
        
        static func == (lh: IdentityHints, rh: IdentityHints) -> Bool {
            return lh.userID == rh.userID && lh.accengageDeviceID == rh.accengageDeviceID
        }
    }
    
    // NOTE: For internal use only. :nodoc:
    @objc(UAQuietTime)
    public class QuietTime : NSObject, Codable {
        @objc
        public let start: String
        
        @objc
        public let end: String
        
        enum CodingKeys: String, CodingKey {
            case start = "start"
            case end = "end"
        }
        
        @objc
        public init(start: String, end: String) {
            self.start = start
            self.end = end
        }
        
        public override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? QuietTime else {
                return false
            }
            
            return self == other
        }
        
        static func == (lh: QuietTime, rh: QuietTime) -> Bool {
            return lh.start == rh.start && lh.end == rh.end
        }
    }
}

