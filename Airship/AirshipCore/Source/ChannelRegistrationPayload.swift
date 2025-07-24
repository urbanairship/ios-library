import Foundation

/// NOTE: For internal use only. :nodoc:
public struct ChannelRegistrationPayload: Codable, Equatable, Sendable {

    public var channel: ChannelInfo

    public var identityHints: IdentityHints?

    enum CodingKeys: String, CodingKey {
        case channel = "channel"
        case identityHints = "identity_hints"
    }

    public init() {
        self.channel = ChannelInfo()
    }

    public func minimizePayload(
        previous: ChannelRegistrationPayload?
    ) -> ChannelRegistrationPayload {
        guard let previous = previous else {
            return self
        }

        var minPayload = self
        minPayload.channel = self.channel.minimize(
            previous: previous.channel
        )
        minPayload.identityHints = nil
        return minPayload
    }

    /// NOTE: For internal use only. :nodoc:
    public struct ChannelInfo: Codable, Equatable, Sendable {

        var deviceType = "ios"

        /// This flag indicates that the user is able to receive push notifications.
        public var isOptedIn: Bool = false

        /// This flag indicates that the user is able to receive background notifications.
        public var isBackgroundEnabled: Bool = false

        /// The address to push notifications to.  This should be the device token.
        public var pushAddress: String?

        /// The flag indicates tags in this request should be handled.
        public var setTags: Bool = false

        /// The tags for this device.
        public var tags: [String]?

        /// Tag changes.
        public var tagChanges: TagChanges?

        /// The locale language for this device.
        public var language: String?

        /// The locale country for this device.
        public var country: String?

        /// The time zone for this device.
        public var timeZone: String?

        /// The flag indicating if the user is active.
        public var isActive: Bool = false

        /// The app version.
        public var appVersion: String?

        /// The sdk version.
        public var sdkVersion: String?

        /// The device model.
        public var deviceModel: String?

        /// The device OS.
        public var deviceOS: String?

        public var contactID: String?
        public var iOSChannelSettings: iOSChannelSettings?
        public var permissions: [String: String]?

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
            case appVersion = "app_version"
            case sdkVersion = "sdk_version"
            case deviceModel = "device_model"
            case deviceOS = "device_os"
            case contactID = "contact_id"
            case iOSChannelSettings = "ios"
            case isActive = "is_activity"
            case permissions = "permissions"
        }

        fileprivate func minimize(previous: ChannelInfo?) -> ChannelInfo {
            guard let previous = previous else { return self }
            var channel = self

            if channel.setTags && previous.setTags {
                if channel.tags == previous.tags {
                    channel.tags = nil
                    channel.setTags = false
                } else {
                    let channelTags = channel.tags ?? []
                    let previousTags = previous.tags ?? []
                    let adds = channelTags.filter { !previousTags.contains($0) }
                    let removes = previousTags.filter { !channelTags.contains($0) }
                    channel.tagChanges = TagChanges(adds: adds, removes: removes)
                }
            }

            if channel.contactID == previous.contactID {
                if channel.language == previous.language {
                    channel.language = nil
                }
                if channel.country == previous.country {
                    channel.country = nil
                }
                if channel.timeZone == previous.timeZone {
                    channel.timeZone = nil
                }
                if channel.appVersion == previous.appVersion {
                    channel.appVersion = nil
                }
                if channel.sdkVersion == previous.sdkVersion {
                    channel.sdkVersion = nil
                }
                if channel.deviceModel == previous.deviceModel {
                    channel.deviceModel = nil
                }
                if channel.deviceOS == previous.deviceOS {
                    channel.deviceOS = nil
                }
            }
            
            if previous.permissions == channel.permissions {
                channel.permissions = nil
            }

            channel.iOSChannelSettings = channel.iOSChannelSettings?.minimize(
                previous: previous.iOSChannelSettings
            )

            return channel
        }
    }

    /// NOTE: For internal use only. :nodoc:
    public struct TagChanges: Codable, Equatable, Sendable {
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
    }

    /// NOTE: For internal use only. :nodoc:
    public struct iOSChannelSettings: Codable, Equatable, Sendable {
        /// Quiet time settings for this device.
        public var quietTime: QuietTime?

        /// Quiet time time zone.
        public var quietTimeTimeZone: String?

        /// The badge for this device.
        public var badge: Int?
        public var isScheduledSummary: Bool?
        public var isTimeSensitive: Bool?

        enum CodingKeys: String, CodingKey {
            case quietTime = "quiettime"
            case quietTimeTimeZone = "tz"
            case badge = "badge"
            case isScheduledSummary = "scheduled_summary"
            case isTimeSensitive = "time_sensitive"
        }

        func minimize(previous: iOSChannelSettings?) -> iOSChannelSettings {
            guard let previous = previous else { return self }

            var minimized = self

            if minimized.isScheduledSummary == previous.isScheduledSummary {
                minimized.isScheduledSummary = nil
            }

            if minimized.isTimeSensitive == previous.isTimeSensitive {
                minimized.isTimeSensitive = nil
            }

            return minimized
        }
    }

    /// NOTE: For internal use only. :nodoc:
    public struct IdentityHints: Codable, Equatable, Sendable {
        /// The user ID.
        public var userID: String?

        public init(userID: String? = nil) {
            self.userID = userID
        }

        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
        }
    }

    /// NOTE: For internal use only. :nodoc:
    public struct QuietTime: Codable, Equatable, Sendable {
        public var start: String
        public var end: String

        enum CodingKeys: String, CodingKey {
            case start = "start"
            case end = "end"
        }
    }
}
