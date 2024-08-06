/* Copyright Airship and Contributors */

import Foundation
import AirshipCore
import AirshipPreferenceCenter

/// Open delegate.
@objc
public protocol OUAPreferenceCenterOpenDelegate {

    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     * - Returns: `true` if the preference center was opened, otherwise `false` to fallback to OOTB UI.
     */
    @objc
    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool
}

public class OUAPreferenceCenterOpenDelegateWrapper: NSObject, PreferenceCenterOpenDelegate {
    private let delegate: OUAPreferenceCenterOpenDelegate
    
    init(delegate: OUAPreferenceCenterOpenDelegate) {
        self.delegate = delegate
    }
    
    public func openPreferenceCenter(_ preferenceCenterID: String) -> Bool {
        return self.delegate.openPreferenceCenter(preferenceCenterID)
    }
}

@objc
public class OUAPreferenceCenter: NSObject {
    
    /// The shared PreferenceCenter instance. `Airship.takeOff` must be called before accessing this instance.
    @objc
    public static var shared: PreferenceCenter {
        return PreferenceCenter.shared
    }
    
    
    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen. Must be set
     * on the main actor.
     */
    private var _openDelegate: PreferenceCenterOpenDelegate?
    @objc
    @MainActor
    public var openDelegate: OUAPreferenceCenterOpenDelegate? {
        didSet {
            if let openDelegate {
                _openDelegate = OUAPreferenceCenterOpenDelegateWrapper(delegate: openDelegate)
                
                PreferenceCenter.shared.openDelegate = _openDelegate
            } else {
                PreferenceCenter.shared.openDelegate = nil
            }
        }
    }
    
    
    @objc
    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        try PreferenceCenter.shared.setThemeFromPlist(plist)
    }
    
    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc(openPreferenceCenter:)
    @MainActor
    public func open(_ preferenceCenterID: String) {
        PreferenceCenter.shared.open(preferenceCenterID)
    }
    
    
    /**
     * Returns the configuration of the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc
    public func config(preferenceCenterID: String) async throws -> PreferenceCenterConfig {
        return try await PreferenceCenter.shared.config(preferenceCenterID: preferenceCenterID)
    }
    
    /**
     * Returns the configuration of the Preference Center as JSON data with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc
    public func jsonConfig(preferenceCenterID: String) async throws -> Data {
        return try await PreferenceCenter.shared.jsonConfig(preferenceCenterID: preferenceCenterID)
    }
}

