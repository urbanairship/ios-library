/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
public import AirshipCore
#endif

/// Open delegate.
@MainActor
public protocol PreferenceCenterOpenDelegate {

    /// Opens the Preference Center with the given ID.
    /// - Parameters:
    ///   - preferenceCenterID: The preference center ID.
    /// - Returns: `true` if the preference center was opened, otherwise `false` to fallback to OOTB UI.
    func openPreferenceCenter(_ preferenceCenterID: String) -> Bool
}

/// An interface for interacting with Airship's Preference Center.
@MainActor
public protocol PreferenceCenterProtocol: Sendable {
    
    /// Called when the Preference Center is requested to be displayed.
    /// Return `true` if the display was handled, `false` to fall back to default SDK behavior.
    var onDisplay: (@MainActor @Sendable (_ preferenceCenterID: String) -> Bool)? { get set }

    /// Open delegate for the Preference Center.
    var openDelegate: (any PreferenceCenterOpenDelegate)? { get set }

    /// The theme for the Preference Center.
    var theme: PreferenceCenterTheme? { get set }

    /// Loads a Preference Center theme from a plist file.
    /// - Parameter plist: The name of the plist in the bundle.
    func setThemeFromPlist(_ plist: String) throws

    /// Displays the Preference Center with the given ID.
    /// - Parameter identifier: The preference center ID.
    func display(identifier: String)

    /// Opens the Preference Center with the given ID. (Deprecated)
    @available(*, deprecated, renamed: "display(identifier:)")
    func open(_ preferenceCenterID: String)

    /// Returns the configuration of the Preference Center with the given ID.
    /// - Parameter preferenceCenterID: The preference center ID.
    func config(preferenceCenterID: String) async throws -> PreferenceCenterConfig

    /// Returns the configuration of the Preference Center as JSON data with the given ID.
    /// - Parameter preferenceCenterID: The preference center ID.
    func jsonConfig(preferenceCenterID: String) async throws -> Data
}


@MainActor
final class PreferenceCenter: PreferenceCenterProtocol {

    /// The shared PreferenceCenter instance. `Airship.takeOff` must be called before accessing this instance.
    @available(*, deprecated, message: "Use Airship.preferenceCenter instead")
    public static var shared: any PreferenceCenterProtocol {
        return Airship.preferenceCenter
    }

    let inputValidator: any AirshipInputValidation.Validator

    private static let payloadType = "preference_forms"
    private static let preferenceFormsKey = "preference_forms"

    private let delegates: Delegates = Delegates()

    public var onDisplay: (@MainActor @Sendable (_ preferenceCenterID: String) -> Bool)?

    public var openDelegate: (any PreferenceCenterOpenDelegate)? {
        get {
            self.delegates.openDelegate
        }
        set {
            self.delegates.openDelegate = newValue
        }
    }

    private let dataStore: PreferenceDataStore
    private let privacyManager: any PrivacyManagerProtocol
    private let remoteData: any RemoteDataProtocol

    private let currentDisplay: AirshipMainActorValue<(any AirshipMainActorCancellable)?> = AirshipMainActorValue(nil)

    private let _theme: AirshipMainActorValue<PreferenceCenterTheme?> = AirshipMainActorValue(nil)

    public var theme: PreferenceCenterTheme? {
        get {
            self._theme.value
        }
        set {
            self._theme.set(newValue)
        }
    }

    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try PreferenceCenterThemeLoader.fromPlist(plist)
    }

    init(
        dataStore: PreferenceDataStore,
        privacyManager: any PrivacyManagerProtocol,
        remoteData: any RemoteDataProtocol,
        inputValidator: any AirshipInputValidation.Validator
    ) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.remoteData = remoteData
        self.inputValidator = inputValidator
        self._theme.set(PreferenceCenterThemeLoader.defaultPlist())
        AirshipLogger.info("PreferenceCenter initialized")
    }


    public func display(identifier: String) {
        let handled: Bool = if let onDisplay {
            onDisplay(identifier)
        } else if let openDelegate {
            openDelegate.openPreferenceCenter(identifier)
        } else {
            false
        }

        guard !handled else {
            AirshipLogger.trace(
                "Preference center \(identifier) display request handled by the app."
            )
            return
        }

        Task {
            await displayDefaultPreferenceCenter(preferenceCenterID: identifier)
        }
    }

    @available(*, deprecated, renamed: "display(identifier:)")
    public func open(_ preferenceCenterID: String) {
        self.display(identifier: preferenceCenterID)
    }

    private func displayDefaultPreferenceCenter(preferenceCenterID: String) async {
        guard let scene = try? AirshipSceneManager.shared.lastActiveScene else {
            AirshipLogger.error("Unable to display, missing scene.")
            return
        }

        currentDisplay.value?.cancel()

        AirshipLogger.debug("Opening default preference center UI")

        self.currentDisplay.set(
            displayPreferenceCenter(
                preferenceCenterID,
                scene: scene,
                theme: theme
            )
        )
    }

    public func config(preferenceCenterID: String) async throws -> PreferenceCenterConfig {
        let data = try await jsonConfig(preferenceCenterID: preferenceCenterID)
        return try PreferenceCenterDecoder.decodeConfig(data: data)
    }

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
}

/// Delegates holder so I can keep the executor sendable
@MainActor
private final class Delegates {
    var openDelegate: (any PreferenceCenterOpenDelegate)?
}

extension PreferenceCenter {

    @MainActor
    fileprivate func displayPreferenceCenter(
        _ preferenceCenterID: String,
        scene: UIWindowScene,
        theme: PreferenceCenterTheme?
    ) -> any AirshipMainActorCancellable {

        var window: UIWindow? = AirshipWindowFactory.shared.makeWindow(windowScene: scene)

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

extension PreferenceCenter {
    @MainActor
    func deepLink(_ deepLink: URL) -> Bool {
        guard deepLink.scheme == Airship.deepLinkScheme,
              deepLink.host == "preferences",
              deepLink.pathComponents.count == 2
        else {
            return false
        }

        let preferenceCenterID = deepLink.pathComponents[1]
        self.display(identifier: preferenceCenterID)
        return true
    }
}

public extension Airship {
    /// The shared PreferenceCenter instance. `Airship.takeOff` must be called before accessing this instance.
    @MainActor
    static var preferenceCenter: any PreferenceCenterProtocol = Airship.requireComponent(
        ofType: PreferenceCenterComponent.self
    )
        .preferenceCenter
}
