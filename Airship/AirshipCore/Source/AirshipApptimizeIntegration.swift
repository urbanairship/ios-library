/* Copyright Airship and Contributors */

import Foundation

/**
 * This class provides handy access for Airship method for the integration with Apptimize SDK
 */

@objc(UAirshipApptimizeIntegration)
final class AirshipApptimizeIntegration: NSObject {
    
    @objc
    public static var airshipVersion: String {
        return AirshipVersion.get()
    }
    
    @objc
    public static var isFlying: Bool {
        return Airship.isFlying
    }
    
    @objc(getUserID:)
    public static func getUserID(completion: @Sendable @escaping (String?) -> Void) {
        guard Airship.isFlying else { return }
        
        Task { @Sendable in
            let id = await Airship.contact.namedUserID
            completion(id)
        }
    }
    
    @objc
    public static var channelID: String? {
        guard Airship.isFlying else { return nil }
        return Airship.channel.identifier
    }
    
    @objc
    public static var channelTags: [String]? {
        guard Airship.isFlying else { return nil }
        return Airship.channel.tags
    }
    
    @objc
    public static func addTags(_ tags: [String], group: String) {
        guard Airship.isFlying else { return }
        
        Airship.channel.editTagGroups { $0.add(tags, group: group) }
    }
    
    @objc
    public static func setTags(_ tags: [String], group: String) {
        guard Airship.isFlying else { return }
        
        Airship.channel.editTagGroups({ $0.set(tags, group: group) })
    }
}
