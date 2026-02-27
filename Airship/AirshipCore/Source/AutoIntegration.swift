/* Copyright Airship and Contributors */

import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class AutoIntegration {
    public static let shared = AutoIntegration()

    private let swizzler: AirshipSwizzler = AirshipSwizzler()
    private let dummyNotificationDelegate = UAAutoIntegrationDummyDelegate()
    weak var delegate: (any AppIntegrationDelegate)?



    public func integrate(with delegate: any AppIntegrationDelegate) {
        self.delegate = delegate

#if os(watchOS)
        performWatchIntegration(delegate: delegate)
#elseif os(macOS)
        performMacIntegration(delegate: delegate)
#else
        performMobileIntegration(delegate: delegate)
#endif
        // Notification Center swizzling (Platform independent)
        swizzleNotificationCenter(delegate: delegate)
    }

    private func swizzleNotificationCenter(delegate: any AppIntegrationDelegate) {
        self.swizzler.swizzleNotificationCenterDelegateSetter(
            delegate: delegate,
            dummyDelegate: self.dummyNotificationDelegate
        )

        if let current = UNUserNotificationCenter.current().delegate {
            self.swizzler.swizzleNotificationCenterDelegate(current, delegate: delegate)
        } else {
            UNUserNotificationCenter.current().delegate = dummyNotificationDelegate
        }
    }

    // MARK: - Platform Specific Integration Logic

#if os(watchOS)
    private func performWatchIntegration(delegate: any AppIntegrationDelegate) {
        // Access via WKApplication (Modern/SwiftUI friendly)
        guard let appDelegate = WKApplication.shared().delegate else {
            AirshipLogger.info("Watch app delegate not set, deferring until didFinishLaunching.")
            NotificationCenter.default.addObserver(
                forName: WKApplication.didFinishLaunchingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.performWatchIntegration(delegate: delegate)
                }
            }
            return
        }

        AirshipLogger.debug("Integrating Airship Auto-Integration (watchOS).")
        self.swizzler.swizzleWatchDidRegister(appDelegate, delegate: delegate)
        self.swizzler.swizzleWatchDidFailToRegister(appDelegate, delegate: delegate)
        self.swizzler.swizzleWatchDidReceiveRemoteNotification(appDelegate, delegate: delegate)
    }

#elseif os(macOS)

    private func performMacIntegration(delegate: any AppIntegrationDelegate) {
        guard let appDelegate = NSApplication.shared.delegate else {
            AirshipLogger.info("macOS app delegate not set, deferring until didFinishLaunching.")
            NotificationCenter.default.addObserver(
                forName: NSApplication.didFinishLaunchingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.performMacIntegration(delegate: delegate)
                }
            }
            return
        }

        AirshipLogger.debug("Integrating Airship Auto-Integration (macOS).")
        self.swizzler.swizzleMacDidRegister(appDelegate, delegate: delegate)
        self.swizzler.swizzleMacDidFailToRegister(appDelegate, delegate: delegate)
        self.swizzler.swizzleMacDidReceiveRemoteNotification(appDelegate, delegate: delegate)
    }

#else

    private func performMobileIntegration(delegate: any AppIntegrationDelegate) {
        guard let appDelegate = UIApplication.shared.delegate else {
            AirshipLogger.info("App delegate not set, deferring until didFinishLaunching.")
            NotificationCenter.default.addObserver(
                forName: UIApplication.didFinishLaunchingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.performMobileIntegration(delegate: delegate)
                }
            }
            return
        }

        AirshipLogger.debug("Integrating Airship Auto-Integration (iOS/tvOS/visionOS).")
        self.swizzler.swizzleDidRegister(appDelegate, delegate: delegate)
        self.swizzler.swizzleDidFailToRegister(appDelegate, delegate: delegate)
        self.swizzler.swizzleDidReceiveRemoteNotification(appDelegate, delegate: delegate)
        self.swizzler.swizzleBackgroundFetch(appDelegate, delegate: delegate)
    }

#endif
}

// MARK: - Default delegate

fileprivate class UAAutoIntegrationDummyDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([])
    }

#if !os(tvOS)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
#endif
}

// MARK: - Notification Center (common)

fileprivate extension AirshipSwizzler {
    private typealias NotificationCenterDelegateSetterBlock = @convention(block) (UNUserNotificationCenter, (any UNUserNotificationCenterDelegate)?) -> Void
    private typealias WillPresentNotificationBlock = @convention(block) (NSObject, UNUserNotificationCenter, UNNotification, @Sendable @escaping (UNNotificationPresentationOptions) -> Void) -> Void

#if !os(tvOS)
    private typealias DidReceiveNotificationResponseBlock = @convention(block) (NSObject, UNUserNotificationCenter, UNNotificationResponse, @Sendable @escaping () -> Void) -> Void
#endif

    func swizzleNotificationCenterDelegateSetter(delegate: any AppIntegrationDelegate, dummyDelegate: UAAutoIntegrationDummyDelegate) {
        let setter = #selector(setter: UNUserNotificationCenter.delegate)
        let block: NotificationCenterDelegateSetterBlock = { [weak self] (center, newDelegate) in
            guard let self else { return }
            if let original = self.originalImplementation(setter, forClass: UNUserNotificationCenter.self) {
                let fn = unsafeBitCast(original, to: (@convention(c) (UNUserNotificationCenter, Selector, (any UNUserNotificationCenterDelegate)?) -> Void).self)
                fn(center, setter, newDelegate)
            }

            if let newDelegate {
                self.swizzleNotificationCenterDelegate(newDelegate, delegate: delegate)
            } else {
                UNUserNotificationCenter.current().delegate = dummyDelegate
            }
        }
        self.swizzleClass(UNUserNotificationCenter.self, selector: setter, implementation: imp_implementationWithBlock(block))
    }

    func swizzleNotificationCenterDelegate(_ delegate: any UNUserNotificationCenterDelegate, delegate integrationDelegate: any AppIntegrationDelegate) {
        swizzleNotificationCenterWillPresent(delegate, delegate: integrationDelegate)

#if !os(tvOS)
        swizzleNotificationCenterDidReceive(delegate, delegate: integrationDelegate)
#endif
    }

    private func swizzleNotificationCenterWillPresent(_ delegate: any UNUserNotificationCenterDelegate, delegate integrationDelegate: any AppIntegrationDelegate) {
        let willPresentSelector = #selector((any UNUserNotificationCenterDelegate).userNotificationCenter(_:willPresent:withCompletionHandler:))
        let willPresentBlock: WillPresentNotificationBlock = { [weak self] (receiver, center, notification, handler) in
            guard receiver === UNUserNotificationCenter.current().delegate else {
                handler([]); return
            }

            let group = DispatchGroup()
            let result: AirshipAtomicValue<UNNotificationPresentationOptions> = AirshipAtomicValue([])

            if
                let strongSelf = self,
                let original = strongSelf.originalImplementation(willPresentSelector, forClass: type(of: receiver))
            {
                group.enter()
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, UNUserNotificationCenter, UNNotification, @escaping (UNNotificationPresentationOptions) -> Void) -> Void).self)
                let safeCompletion = strongSelf.ensureOnce(selector: willPresentSelector) { options in
                    result.update { $0.union(options) }
                    group.leave()
                }
                fn(receiver, willPresentSelector, center, notification, safeCompletion)
            }

            group.enter()
            integrationDelegate.presentationOptions(for: notification) { options in
                result.update { $0.union(options) }
                group.leave()
            }

            group.notify(queue: .main) {
                integrationDelegate.willPresentNotification(notification: notification, presentationOptions: result.value) {
                    handler(result.value)
                }
            }
        }
        self.swizzleInstance(
            delegate,
            selector: willPresentSelector,
            protocol: (any UNUserNotificationCenterDelegate).self,
            implementation: imp_implementationWithBlock(willPresentBlock)
        )
    }

#if !os(tvOS)
    private func swizzleNotificationCenterDidReceive(_ delegate: any UNUserNotificationCenterDelegate, delegate integrationDelegate: any AppIntegrationDelegate) {
        let responseSelector = #selector((any UNUserNotificationCenterDelegate).userNotificationCenter(_:didReceive:withCompletionHandler:))
        let responseBlock: DidReceiveNotificationResponseBlock = { [weak self] (receiver, center, response, handler) in
            guard receiver === UNUserNotificationCenter.current().delegate else {
                handler(); return
            }

            let group = DispatchGroup()
            if
                let strongSelf = self,
                let original = strongSelf.originalImplementation(responseSelector, forClass: type(of: receiver))
            {
                group.enter()
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, UNUserNotificationCenter, UNNotificationResponse, @escaping () -> Void) -> Void).self)
                let safeCompletion = strongSelf.ensureOnce(selector: responseSelector) {
                    group.leave()
                }
                fn(receiver, responseSelector, center, response, safeCompletion)
            }

            group.enter()
            integrationDelegate.didReceiveNotificationResponse(response: response) { group.leave() }

            group.notify(queue: .main) { handler() }
        }

        self.swizzleInstance(
            delegate,
            selector: responseSelector,
            protocol: (any UNUserNotificationCenterDelegate).self,
            implementation: imp_implementationWithBlock(responseBlock)
        )
    }
#endif
}

#if os(watchOS)

// MARK: - App Delegate watchOS
extension AirshipSwizzler {
    private typealias WatchDidRegisterForRemoteNotificationsBlock = @convention(block) (NSObject, Data) -> Void
    private typealias WatchDidReceiveRemoteNotificationBlock = @convention(block) (NSObject, [AnyHashable: Any], @escaping (WKBackgroundFetchResult) -> Void) -> Void
    private typealias WatchDidFailToRegisterBlock = @convention(block) (NSObject, any Error) -> Void

    func swizzleWatchDidRegister(_ delegate: any NSObjectProtocol, delegate integrationDelegate: any AppIntegrationDelegate) {
        let regSelector = #selector((any WKExtensionDelegate).didRegisterForRemoteNotifications(withDeviceToken:))
        let regBlock: WatchDidRegisterForRemoteNotificationsBlock = { [weak self] (receiver, token) in
            integrationDelegate.didRegisterForRemoteNotifications(deviceToken: token)
            if let strongSelf = self, let original = strongSelf.originalImplementation(regSelector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, Data) -> Void).self)
                fn(receiver, regSelector, token)
            }
        }
        self.swizzleInstance(
            delegate,
            selector: regSelector,
            protocol: (any WKExtensionDelegate).self,
            implementation: imp_implementationWithBlock(regBlock)
        )
    }

    func swizzleWatchDidReceiveRemoteNotification(_ delegate: any NSObjectProtocol, delegate integrationDelegate: any AppIntegrationDelegate) {
        let selector = #selector((any WKExtensionDelegate).didReceiveRemoteNotification(_:fetchCompletionHandler:))

        let block: WatchDidReceiveRemoteNotificationBlock = { [weak self] (receiver, userInfo, handler) in
            let resultValue: AirshipAtomicValue<WKBackgroundFetchResult> = AirshipAtomicValue(.noData)
            let group = DispatchGroup()

            let updateResult: @Sendable (WKBackgroundFetchResult) -> Void = { next in
                resultValue.update { current in
                    // Logic: .newData wins, otherwise .failed wins over .noData
                    return (current == .newData || next == .newData) ? .newData : (next == .failed ? .failed : current)
                }
            }

            if let strongSelf = self, let original = strongSelf.originalImplementation(selector, forClass: type(of: receiver)) {
                group.enter()
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, [AnyHashable: Any], @escaping (WKBackgroundFetchResult) -> Void) -> Void).self)
                let safeCompletion = strongSelf.ensureOnce(selector: selector) { res in
                    updateResult(res)
                    group.leave()
                }
                fn(receiver, selector, userInfo, safeCompletion)
            }

            group.enter()

            // watchOS doesn't have applicationState == .active in the same way,
            // but you can check if the app is in the foreground via WKApplication
            let isForeground = WKApplication.shared().applicationState == .active
            integrationDelegate.didReceiveRemoteNotification(userInfo: userInfo, isForeground: isForeground) { res in
                updateResult(res)
                group.leave()
            }

            group.notify(queue: .main) {
                handler(resultValue.value)
            }
        }

        self.swizzleInstance(
            delegate,
            selector: selector,
            protocol: (any WKExtensionDelegate).self,
            implementation: imp_implementationWithBlock(block)
        )
    }

    func swizzleWatchDidFailToRegister(_ delegate: any NSObjectProtocol, delegate integrationDelegate: any AppIntegrationDelegate) {
        let selector = #selector((any WKExtensionDelegate).didFailToRegisterForRemoteNotificationsWithError(_:))

        let block: WatchDidFailToRegisterBlock = { [weak self] (receiver, error) in
            integrationDelegate.didFailToRegisterForRemoteNotifications(error: error)

            if let strongSelf = self,
               let original = strongSelf.originalImplementation(selector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, any Error) -> Void).self)
                fn(receiver, selector, error)
            }
        }

        self.swizzleInstance(
            delegate,
            selector: selector,
            protocol: (any WKExtensionDelegate).self,
            implementation: imp_implementationWithBlock(block)
        )
    }
}



#elseif os(macOS)

// MARK: - App Delegate macOS
extension AirshipSwizzler {
    private typealias MacDidRegisterBlock = @convention(block) (NSObject, NSApplication, Data) -> Void
    private typealias MacDidFailBlock = @convention(block) (NSObject, NSApplication, any Error) -> Void
    private typealias MacDidReceiveRemoteNotificationBlock = @convention(block) (NSObject, [AnyHashable: Any]) -> Void

    func swizzleMacDidRegister(_ appDelegate: any NSApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let selector = #selector((any NSApplicationDelegate).application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
        let block: MacDidRegisterBlock = { [weak self] (receiver, app, token) in
            delegate.didRegisterForRemoteNotifications(deviceToken: token)
            if let strongSelf = self, let original = strongSelf.originalImplementation(selector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, NSApplication, Data) -> Void).self)
                fn(receiver, selector, app, token)
            }
        }
        self.swizzleInstance(appDelegate, selector: selector, protocol: (any NSApplicationDelegate).self, implementation: imp_implementationWithBlock(block))
    }

    func swizzleMacDidFailToRegister(_ appDelegate: any NSApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let selector = #selector((any NSApplicationDelegate).application(_:didFailToRegisterForRemoteNotificationsWithError:))
        let block: MacDidFailBlock = { [weak self] (receiver, app, error) in
            delegate.didFailToRegisterForRemoteNotifications(error: error)
            if let strongSelf = self, let original = strongSelf.originalImplementation(selector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, NSApplication, any Error) -> Void).self)
                fn(receiver, selector, app, error)
            }
        }
        self.swizzleInstance(appDelegate, selector: selector, protocol: (any NSApplicationDelegate).self, implementation: imp_implementationWithBlock(block))
    }

    func swizzleMacDidReceiveRemoteNotification(_ appDelegate: any NSApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let selector = #selector((any NSApplicationDelegate).application(_:didReceiveRemoteNotification:))
        let block: MacDidReceiveRemoteNotificationBlock = { [weak self] (receiver, userInfo) in
            let isForeground = NSApplication.shared.isActive
            delegate.didReceiveRemoteNotification(userInfo: userInfo, isForeground: isForeground)
            if let strongSelf = self,
               let original = strongSelf.originalImplementation(selector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, [AnyHashable: Any]) -> Void).self)
                fn(receiver, selector, userInfo)
            }
        }

        self.swizzleInstance(
            appDelegate,
            selector: selector,
            protocol: (any NSApplicationDelegate).self,
            implementation: imp_implementationWithBlock(block)
        )
    }
}

#else

// MARK: - App Delegate tvOS, ipadOS, iOS
fileprivate extension AirshipSwizzler {
    private typealias DidRegisterForRemoteNotificationsBlock = @convention(block) (NSObject, UIApplication, Data) -> Void
    private typealias DidFailToRegisterForRemoteNotificationsBlock = @convention(block) (NSObject, UIApplication, any Error) -> Void
    private typealias DidReceiveRemoteNotificationFetchBlock = @convention(block) (NSObject, UIApplication, [AnyHashable: Any], @Sendable @escaping (UIBackgroundFetchResult) -> Void) -> Void
    private typealias BackgroundFetchBlock = @convention(block) (NSObject, UIApplication, @Sendable @escaping (UIBackgroundFetchResult) -> Void) -> Void

    func swizzleDidRegister(_ appDelegate: any UIApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let regSelector = #selector((any UIApplicationDelegate).application(_:didRegisterForRemoteNotificationsWithDeviceToken:))
        let regBlock: DidRegisterForRemoteNotificationsBlock = { [weak self] (receiver, app, token) in
            delegate.didRegisterForRemoteNotifications(deviceToken: token)
            if let strongSelf = self, let original = strongSelf.originalImplementation(regSelector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, UIApplication, Data) -> Void).self)
                fn(receiver, regSelector, app, token)
            }
        }

        self.swizzleInstance(
            appDelegate,
            selector: regSelector,
            protocol: (any UIApplicationDelegate).self,
            implementation: imp_implementationWithBlock(regBlock)
        )
    }

    func swizzleDidFailToRegister(_ appDelegate: any UIApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let failSelector = #selector((any UIApplicationDelegate).application(_:didFailToRegisterForRemoteNotificationsWithError:))
        let failBlock: DidFailToRegisterForRemoteNotificationsBlock = { [weak self] (receiver, app, error) in
            delegate.didFailToRegisterForRemoteNotifications(error: error)
            if let strongSelf = self, let original = strongSelf.originalImplementation(failSelector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, UIApplication, any Error) -> Void).self)
                fn(receiver, failSelector, app, error)
            }
        }

        self.swizzleInstance(
            appDelegate,
            selector: failSelector,
            protocol: (any UIApplicationDelegate).self,
            implementation: imp_implementationWithBlock(failBlock)
        )
    }

    func swizzleDidReceiveRemoteNotification(_ appDelegate: any UIApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let fetchSelector = #selector((any UIApplicationDelegate).application(_:didReceiveRemoteNotification:fetchCompletionHandler:))

        let fetchBlock: DidReceiveRemoteNotificationFetchBlock = { [weak self] (receiver, app, userInfo, handler) in
            let resultValue: AirshipAtomicValue<UIBackgroundFetchResult> = AirshipAtomicValue(.noData)
            let group = DispatchGroup()

            let updateResult: @Sendable (UIBackgroundFetchResult) -> Void = { next in
                resultValue.update { current in
                    return (current == .newData || next == .newData) ? .newData : (next == .failed ? .failed : current)
                }
            }

            if
                let strongSelf = self,
                let original = strongSelf.originalImplementation(fetchSelector, forClass: type(of: receiver))
            {
                group.enter()
                typealias RawFetchFunc = @convention(c) (NSObject, Selector, UIApplication, [AnyHashable: Any], @escaping (UIBackgroundFetchResult) -> Void) -> Void
                let fn = unsafeBitCast(original, to: RawFetchFunc.self)

                let safeCompletion = strongSelf.ensureOnce(selector: fetchSelector) { res in
                    updateResult(res)
                    group.leave()
                }
                fn(receiver, fetchSelector, app, userInfo, safeCompletion)
            }

            group.enter()
            delegate.didReceiveRemoteNotification(userInfo: userInfo, isForeground: app.applicationState == .active) { res in
                updateResult(res)
                group.leave()
            }

            group.notify(queue: .main) { handler(resultValue.value) }
        }

        self.swizzleInstance(
            appDelegate,
            selector: fetchSelector,
            protocol: (any UIApplicationDelegate).self,
            implementation: imp_implementationWithBlock(fetchBlock)
        )
    }

    func swizzleBackgroundFetch(_ appDelegate: any UIApplicationDelegate, delegate: any AppIntegrationDelegate) {
        let backgroundSelector = #selector((any UIApplicationDelegate).application(_:performFetchWithCompletionHandler:))
        let backgroundBlock: BackgroundFetchBlock = { [weak self] (receiver, app, handler) in
            delegate.onBackgroundAppRefresh()
            if let strongSelf = self, let original = strongSelf.originalImplementation(backgroundSelector, forClass: type(of: receiver)) {
                let fn = unsafeBitCast(original, to: (@convention(c) (NSObject, Selector, UIApplication, @escaping (UIBackgroundFetchResult) -> Void) -> Void).self)
                let safeCompletion = strongSelf.ensureOnce(selector: backgroundSelector, completion: handler)
                fn(receiver, backgroundSelector, app, safeCompletion)
            } else {
                handler(.noData)
            }
        }

        self.swizzleInstance(
            appDelegate,
            selector: backgroundSelector,
            protocol: (any UIApplicationDelegate).self,
            implementation: imp_implementationWithBlock(backgroundBlock)
        )
    }
}
#endif


fileprivate extension AirshipSwizzler {
    func ensureOnce<T>(selector: Selector, completion: @escaping (T) -> Void) -> (T) -> Void {
        let called = AirshipAtomicValue(false)
        return { value in
            if called.compareAndSet(expected: false, value: true) {
                completion(value)
            } else {
                AirshipLogger.error(
                    """
                    Completion handler for \(selector) was called multiple times. 
                    Airship has ignored the extra calls to prevent a crash, but you should 
                    check your delegate implementation to ensure the handler is called exactly once.
                    """
                )
            }
        }
    }

    func ensureOnce(selector: Selector, completion: @escaping () -> Void) -> () -> Void {
        let called = AirshipAtomicValue(false)
        return {
            if called.compareAndSet(expected: false, value: true) {
                completion()
            } else {
                AirshipLogger.error(
                    """
                    Completion handler for \(selector) was called multiple times. 
                    Airship has ignored the extra calls to prevent a crash, but you should 
                    check your delegate implementation to ensure the handler is called exactly once.
                    """
                )
            }
        }
    }
}
