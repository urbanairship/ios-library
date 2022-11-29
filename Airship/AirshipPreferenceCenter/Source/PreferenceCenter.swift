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
public class PreferenceCenter: NSObject, Component {

    /// The shared PreferenceCenter instance.
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
    private let privacyManager: PrivacyManager
    private let remoteDataProvider: RemoteDataProvider
    private var currentDisplay: Disposable?

    /**
     * Preference center theme
     */
    public var theme: PreferenceCenterTheme?

    @objc(setTheme:)
    public func _setTheme(_ theme: _PreferenceCenterThemeObjc) {
        self.theme = theme.toPreferenceCenterTheme()
    }

    public func setThemeFromPlist(_ plist: String) throws {
        self.theme = try PreferenceCenterThemeLoader.fromPlist(plist)
    }

    private let disableHelper: ComponentDisableHelper

    // NOTE: For internal use only. :nodoc:
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
        privacyManager: PrivacyManager,
        remoteDataProvider: RemoteDataProvider
    ) {
        self.dataStore = dataStore
        self.privacyManager = privacyManager
        self.remoteDataProvider = remoteDataProvider
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
        guard let scene = try? Utils.findWindowScene() else {
            AirshipLogger.error("Unable to display, missing scene.")
            return
        }

        currentDisplay?.dispose()

        AirshipLogger.debug("Opening default preference center UI")

        self.currentDisplay = showPreferenceCenter(
            preferenceCenterID,
            scene: scene,
            theme: theme
        )
    }

    /**
     * Returns the configuration of the Preference Center with the given ID trough a callback method.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     *   - completionHandler: The completion handler that will receive the requested PreferenceCenterConfig
     */
    @objc(configForPreferenceCenterID:completionHandler:)
    @discardableResult
    public func config(
        preferenceCenterID: String,
        completionHandler: @escaping (PreferenceCenterConfig?) -> Void
    ) -> Disposable {
        var disposable: Disposable!
        disposable = self.remoteDataProvider.subscribe(types: [
            PreferenceCenter.payloadType
        ]) { payloads in

            guard
                let preferences =
                    payloads.first?.data[PreferenceCenter.preferenceFormsKey]
                    as? [[AnyHashable: Any]]
            else {
                disposable.dispose()
                completionHandler(nil)
                return
            }

            let responses: [PrefrenceCenterResponse] = preferences.compactMap {
                do {
                    return try PreferenceCenterDecoder.decodeConfig(object: $0)
                } catch {
                    AirshipLogger.error(
                        "Failed to parse preference center config \(error)"
                    )
                    return nil
                }
            }

            let config = responses.first {
                $0.config.identifier == preferenceCenterID
            }?
            .config
            disposable.dispose()
            completionHandler(config)
        }

        return disposable
    }

    /**
     * Returns the configuration of the Preference Center with the given ID.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     */
    public func config(preferenceCenterID: String) async throws
        -> PreferenceCenterConfig
    {
        return try await withCheckedThrowingContinuation { continuation in
            self.config(preferenceCenterID: preferenceCenterID) { config in
                guard let config = config else {
                    continuation.resume(
                        throwing: AirshipErrors.error("Config not available")
                    )
                    return
                }

                continuation.resume(returning: config)
            }
        }
    }

    /**
     * Returns the raw json of the Preference Center configuration with the given ID through a callback method.
     * - Parameters:
     *   - preferenceCenterID: The preference center ID.
     *   - completionHandler: The completion handler that will receive the requested PreferenceCenterConfig
     */
    @objc(jsonConfigForPreferenceCenterID:completionHandler:)
    @discardableResult
    public func jsonConfig(
        preferenceCenterID: String,
        completionHandler: @escaping ([String: Any]) -> Void
    ) -> Disposable {
        return self.remoteDataProvider.subscribe(types: [
            PreferenceCenter.payloadType
        ]) { payloads in
            let data =
                payloads.first?.data["preference_forms"] as? [[String: Any]]
            let config = data?
                .compactMap { $0["form"] as? [String: Any] }
                .first(where: { $0["id"] as? String == preferenceCenterID })

            completionHandler(config ?? [:])
        }
    }

    // NOTE: For internal use only. :nodoc:
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

    fileprivate func showPreferenceCenter(
        _ preferenceCenterID: String,
        scene: UIWindowScene,
        theme: PreferenceCenterTheme?
    ) -> Disposable {

        let navController = makeNavController(
            theme: theme?.viewController?.navigationBar
        )
        var window: UIWindow? = UIWindow(windowScene: scene)

        let disposable = Disposable {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }

        var viewController: UIViewController!

        viewController =
            PreferenceCenterViewControllerFactory.makeViewController(
                view: PreferenceCenterView(
                    preferenceCenterID: preferenceCenterID
                ),
                preferenceCenterTheme: theme
            )

        navController.pushViewController(viewController, animated: false)
        viewController.navigationItem.leftBarButtonItem = DoneBarButtonItem {
            disposable.dispose()
        }

        window?.windowLevel = .alert
        window?.makeKeyAndVisible()
        window?.rootViewController = navController

        return disposable
    }

    private func makeNavController(theme: PreferenceCenterTheme.NavigationBar?)
        -> UINavigationController
    {
        let navController = UINavigationController(nibName: nil, bundle: nil)
        navController.modalTransitionStyle =
            UIModalTransitionStyle.crossDissolve
        navController.modalPresentationStyle =
            UIModalPresentationStyle.fullScreen

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        var titleTextAttributes: [NSAttributedString.Key: Any] = [:]
        titleTextAttributes[.font] = theme?.titleFont
        titleTextAttributes[.foregroundColor] = theme?.titleColor

        if let tintColor = theme?.tintColor {
            navController.navigationBar.tintColor = tintColor
        }

        if let backgroundColor = theme?.backgroundColor {
            navController.navigationBar.backgroundColor = backgroundColor
            appearance.backgroundColor = backgroundColor
        }

        if !titleTextAttributes.isEmpty {
            navController.navigationBar.titleTextAttributes =
                titleTextAttributes
            appearance.titleTextAttributes = titleTextAttributes
        }

        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        return navController
    }
}

class DoneBarButtonItem: UIBarButtonItem {
    typealias ActionHandler = () -> Void

    private var actionHandler: ActionHandler?

    convenience init(actionHandler: ActionHandler?) {
        self.init(
            barButtonSystemItem: .done,
            target: nil,
            action: #selector(done)
        )
        target = self
        self.actionHandler = actionHandler
    }

    @objc func done() {
        actionHandler?()
    }
}
