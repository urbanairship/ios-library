/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
import AirshipPreferenceCenter
#endif

/// Open delegate.
@objc
public protocol UAPreferenceCenterOpenDelegate {

    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     * - Returns: `true` if the preference center was opened, otherwise `false` to fallback to OOTB UI.
     */
    @objc
    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool
}

fileprivate final class UAPreferenceCenterOpenDelegateWrapper: NSObject, PreferenceCenterOpenDelegate {
    weak var forwardDelegate: (any UAPreferenceCenterOpenDelegate)?

    init(_ forwardDelegate: any UAPreferenceCenterOpenDelegate) {
        self.forwardDelegate = forwardDelegate
    }
    
    public func openPreferenceCenter(_ preferenceCenterID: String) -> Bool {
        return self.forwardDelegate?.openPreferenceCenter(preferenceCenterID) ?? false
    }
}

/// Airship PreferenceCenter module.
@objc
public final class UAPreferenceCenter: NSObject, Sendable {

    @MainActor
    private let storage = Storage()

    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen. Must be set
     * on the main actor.
     */
    @objc
    @MainActor
    public weak var openDelegate: (any UAPreferenceCenterOpenDelegate)? {
        get {
            guard let wrapped = Airship.preferenceCenter.openDelegate as? UAPreferenceCenterOpenDelegateWrapper else {
                return nil
            }
            return wrapped.forwardDelegate
        }

        set {
            if let newValue {
                let wrapper = UAPreferenceCenterOpenDelegateWrapper(newValue)
                Airship.preferenceCenter.openDelegate = wrapper
                storage.openDelegate = wrapper
            } else {
                Airship.preferenceCenter.openDelegate = nil
                storage.openDelegate = nil
            }
        }
    }
    
    @objc
    @MainActor
    public func setThemeFromPlist(_ plist: String) throws {
        try  Airship.preferenceCenter.setThemeFromPlist(plist)
    }
    
    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc(openPreferenceCenter:)
    @MainActor
    public func open(_ preferenceCenterID: String) {
        Airship.preferenceCenter.open(preferenceCenterID)
    }
    
    /**
     * Returns the configuration of the Preference Center as JSON data with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc
    public func jsonConfig(preferenceCenterID: String) async throws -> Data {
        return try await Airship.preferenceCenter.jsonConfig(preferenceCenterID: preferenceCenterID)
    }

    @MainActor
    fileprivate final class Storage  {
        var openDelegate: (any PreferenceCenterOpenDelegate)?
    }
}

