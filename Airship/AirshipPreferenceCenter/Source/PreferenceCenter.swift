/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Open delegate.
@objc(UAPreferenceCenterOpenDelegate)
public protocol PreferenceCenterOpenDelegate {

    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     * - Returns: `true` if the preference center was opened, otherwise `false` to fallback to OOTB UI.
     */
    @objc
    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool
}

/// Airship PreferenceCenter module.
@objc(UAPreferenceCenter)
public class PreferenceCenter: NSObject, AirshipComponent {

    /// The shared PreferenceCenter instance. `Airship.takeOff` must be called before accessing this instance.
    @objc
    public static var shared: PreferenceCenter {
        return Airship.requireComponent(ofType: PreferenceCenter.self)
    }

    private static let payloadType = "preference_forms"
    private static let preferenceFormsKey = "preference_forms"

    /**
     * Open delegate.
     *
     * If set, the delegate will be called instead of launching the OOTB preference center screen.
     */
    @objc
    public weak var openDelegate: PreferenceCenterOpenDelegate?

    private let dataStore: PreferenceDataStore
    private let privacyManager: AirshipPrivacyManager
    private let remoteData: RemoteDataProtocol
    private var currentDisplay: AirshipMainActorCancellable?

    /**
     * Preference center theme
     */
    public var theme: PreferenceCenterTheme?

    @objc
    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try PreferenceCenterThemeLoader.fromPlist(plist)
    }

    private let disableHelper: ComponentDisableHelper

    /// NOTE: For internal use only. :nodoc:
    public var isComponentEnabled: Bool {
        get {
            return disableHelper.enabled
        }
        set {
            disableHelper.enabled = newValue
        }
    }

    init(
        dataStore: PreferenceDataStore,
        privacyManager: AirshipPrivacyManager,
        remoteData: RemoteDataProtocol
    ) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.remoteData = remoteData
        self.theme = PreferenceCenterThemeLoader.defaultPlist()
        self.disableHelper = ComponentDisableHelper(
            dataStore: dataStore,
            className: "PreferenceCenter"
        )
        super.init()
        AirshipLogger.info("PreferenceCenter initialized")
    }

    /**
     * Opens the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc(openPreferenceCenter:)
    public func open(_ preferenceCenterID: String) {
        if self.openDelegate?.openPreferenceCenter(preferenceCenterID) == true {
            AirshipLogger.trace(
                "Preference center \(preferenceCenterID) opened through delegate"
            )
        } else {
            AirshipLogger.trace("Launching OOTB preference center")
            Task {
                await openDefaultPreferenceCenter(
                    preferenceCenterID: preferenceCenterID
                )
            }
        }
    }

    @MainActor
    private func openDefaultPreferenceCenter(preferenceCenterID: String) async {
        guard let scene = try? AirshipUtils.findWindowScene() else {
            AirshipLogger.error("Unable to display, missing scene.")
            return
        }

        currentDisplay?.cancel()

        AirshipLogger.debug("Opening default preference center UI")

        self.currentDisplay = showPreferenceCenter(
            preferenceCenterID,
            scene: scene,
            theme: theme
        )
    }

    /**
     * Returns the configuration of the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc
    public func config(preferenceCenterID: String) async throws -> PreferenceCenterConfig {
        let data = try await jsonConfig(preferenceCenterID: preferenceCenterID)
        return try PreferenceCenterDecoder.decodeConfig(data: data)
    }

    /**
     * Returns the configuration of the Preference Center as JSON data with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    @objc
    public func jsonConfig(preferenceCenterID: String) async throws -> Data {
        let payloads = await self.remoteData.payloads(types: ["preference_forms"])

        for payload in payloads {
            let config = payload.data(key: "preference_forms") as? [[AnyHashable: Any]]

            let form = config?
                .compactMap { $0["form"] as? [AnyHashable: Any] }
                .first(where: { $0["id"] as? String == preferenceCenterID })

            if let form = form {
                return try JSONSerialization.data(
                    withJSONObject: form,
                    options: []
                )
            }
        }

        throw AirshipErrors.error("Preference center not found \(preferenceCenterID)")
    }

    /// NOTE: For internal use only. :nodoc:
    public func deepLink(_ deepLink: URL) -> Bool {
        guard deepLink.scheme == Airship.deepLinkScheme,
            deepLink.host == "preferences",
            deepLink.pathComponents.count == 2
        else {
            return false
        }

        let preferenceCenterID = deepLink.pathComponents[1]
        self.open(preferenceCenterID)
        return true
    }
}

extension PreferenceCenter {

    @MainActor
    fileprivate func showPreferenceCenter(
        _ preferenceCenterID: String,
        scene: UIWindowScene,
        theme: PreferenceCenterTheme?
    ) -> AirshipMainActorCancellable {

        var window: UIWindow? = UIWindow(windowScene: scene)

        let cancellable = AirshipMainActorCancellableBlock {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        var viewController: UIViewController!

        viewController = PreferenceCenterViewControllerFactory.makeViewController(
            view: PreferenceCenterView(
                preferenceCenterID: preferenceCenterID
            ),
            preferenceCenterTheme: theme,
            dismissAction: {
                cancellable.cancel()
            })

        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = viewController

        return cancellable
    }
}
