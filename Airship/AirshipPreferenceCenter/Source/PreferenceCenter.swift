/* Copyright Airship and Contributors */

import Foundation;

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Open delegate.
 */
@objc(UAPreferenceCenterOpenDelegate)
public protocol PreferenceCenterOpenDelegate {

    /**
     * Opens the Preference Center with the given ID.
     * @param id The ID of the preference center.
     */
    @objc
    func open(id: String)
}

/**
 * Airship PreferenceCenter module.
 */
@objc(UAirshipPreferenceCenter)
public class PreferenceCenter : UAComponent {
    
    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen.
     */
    @objc
    public weak var openDelegate: PreferenceCenterOpenDelegate?
    
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
    
    /**
     * Opens the Preference Center with the given ID.
     * @param preferenceCenterId The ID of the preference center.
     */
    @objc
    private func open(preferenceCenterId: String) {
        if let strongDelegate = self.openDelegate {
            AirshipLogger.trace("Opening preference center \(preferenceCenterId) through delegate")
            strongDelegate.open(id: preferenceCenterId)
        } else {
            AirshipLogger.trace("Launching OOTB preference center")
            openDefaultPreferenceCenter(preferenceCenterId: preferenceCenterId)
        }
    }
    
    /**
     * Opens the OOTB Preference Center with the given ID.
     * @param preferenceCenterId The ID of the preference center.
     */
    @objc
    private func openDefaultPreferenceCenter(preferenceCenterId: String) {
        
    }

    /**
     * Returns the configuration of the Preference Center with the given ID trough a callback method.
     * @param preferenceCenterId The ID of the Preference Center.
     * @param callback The callback that will receive the requested PreferenceCenterConfig
     */
    @objc
    private func getConfig(preferenceCenterId: String, callback: @escaping (PreferenceCenterConfig?, Error?) -> ()) {
        callback(nil, nil)
        return
    }
}
