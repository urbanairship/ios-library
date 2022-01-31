/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Common display info.
 */
@objc(UAPreferenceCommonDisplay)
public class CommonDisplay : NSObject, Decodable {
    
    /**
     * The optional name/title.
     */
    @objc
    public let title: String?
    
    /**
     * The optional description/subtitle.
     */
    @objc
    public let subtitle: String?
    
    /**
     * The optional icon URL.
     */
    @objc
    public let iconURL: String?
    
    enum CodingKeys: String, CodingKey {
        case title = "name"
        case subtitle = "description"
        case iconURL = "icon"
    }
}

