/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Preference center config.
 */
@objc(UAPreferenceCenterConfig)
public class PreferenceCenterConfig : NSObject, Decodable {
    
    let typedSections: [TypedSections]
    
    /**
     * The config identifier.
     */
    @objc
    public let identifier: String
    
    /**
     * The preference center sections.
     */
    @objc
    public lazy var sections: [Section] = {
        return typedSections.map { $0.section }
    }()
        
    /**
     * Optional common display info.
     */
    @objc
    public let display: CommonDisplay?

    /**
     * Optional preference center options.
     */
    @objc
    public let options: Options?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case typedSections = "sections"
        case display = "display"
        case options = "options"

    }

    @objc(UAPreferenceCenterConfigOptions)
    public class Options : NSObject, Decodable {

        /**
         * The config identifier.
         */
        @objc
        public let mergeChannelDataToContact: Bool

        enum CodingKeys: String, CodingKey {
            case mergeChannelDataToContact = "merge_channel_data_to_contact"
        }

        public required init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let mergeChannelDataToContact = try? container.decode(Bool.self) {
                self.mergeChannelDataToContact = mergeChannelDataToContact
            } else {
                self.mergeChannelDataToContact = false
            }
        }
    }
}
