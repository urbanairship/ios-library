/* Copyright Airship and Contributors */

import Foundation;

#if canImport(AirshipCore)
import AirshipCore
#endif

/**
 * Airship PreferenceCenter module.
 */
@objc(UAirshipPreferenceCenter)
public class PreferenceCenter : UAComponent {
    
    private let dataStore: UAPreferenceDataStore
    private let channel: UAChannel
    private let privacyManager: UAPrivacyManager
    
    init(dataStore: UAPreferenceDataStore, config: UARuntimeConfig, channel: UAChannel, privacyManager: UAPrivacyManager) {
        self.dataStore = dataStore
        self.channel = channel
        self.privacyManager = privacyManager
        
        super.init(dataStore: dataStore)
        
        AirshipLogger.info("PreferenceCenter initialized")
    }
}
