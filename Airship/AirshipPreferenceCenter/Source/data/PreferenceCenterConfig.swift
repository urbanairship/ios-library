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
    
    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case typedSections = "sections"
        case display = "display"
    }

}
