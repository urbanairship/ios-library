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
    
    private static let payloadType = "preference_forms"
    private static let preferenceFormsKey = "preference_forms"
    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen.
     */
    @objc
    public weak var openDelegate: PreferenceCenterOpenDelegate?
    
    private let dataStore: UAPreferenceDataStore
    private let privacyManager: UAPrivacyManager
    private let remoteDataProvider: UARemoteDataProvider
    
    init(dataStore: UAPreferenceDataStore, privacyManager: UAPrivacyManager, remoteDataProvider: UARemoteDataProvider) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.remoteDataProvider = remoteDataProvider
        super.init(dataStore: dataStore)
        AirshipLogger.info("PreferenceCenter initialized")
    }
    
    /**
     * Opens the Preference Center with the given ID.
     * @param preferenceCenterId The ID of the preference center.
     */
    @objc(openPreferenceCenter:)
    public func open(_ preferenceCenterId: String) {
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
    private func openDefaultPreferenceCenter(preferenceCenterId: String) {
        
    }

    /**
     * Returns the configuration of the Preference Center with the given ID trough a callback method.
     * @param preferenceCenterID The ID of the Preference Center.
     * @param completionHandler The completion handler that will receive the requested PreferenceCenterConfig
     */
    @objc(configForPreferenceCenterID:completionHandler:)
    @discardableResult
    public func config(preferenceCenterID: String, completionHandler: @escaping (PreferenceCenterConfig?) -> ()) -> UADisposable {
        return self.remoteDataProvider.subscribe(withTypes: [PreferenceCenter.payloadType]) { payloads in
            
            guard let preferences = payloads.first?.data[PreferenceCenter.preferenceFormsKey] as? [[AnyHashable : Any]] else {
                completionHandler(nil)
                return
            }
            
            let responses : [PrefrenceCenterResponse] = preferences.compactMap {
                do {
                    return try PreferenceCenterDecoder.decodeConfig(object: $0)
                } catch {
                    AirshipLogger.error("Failed to parse preference center config \(error)")
                    return nil
                }
            }
            
            let config = responses.first { $0.config.identifier == preferenceCenterID }?.config
            completionHandler(config)
        }
    }
}
