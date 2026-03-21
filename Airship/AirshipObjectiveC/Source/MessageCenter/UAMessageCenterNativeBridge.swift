/* Copyright Airship and Contributors */

#if !os(tvOS)

public import Foundation
public import WebKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipMessageCenter
#endif

/// Delegate for native bridge events from Message Center web views.
@objc
public protocol UAMessageCenterNativeBridgeDelegate: NSObjectProtocol {
    /// Called when `UAirship.close()` is triggered from the JavaScript environment.
    func close()
}

private final class NativeBridgeDelegateWrapper: NativeBridgeDelegate {
    weak var delegate: (any UAMessageCenterNativeBridgeDelegate)?

    init(_ delegate: any UAMessageCenterNativeBridgeDelegate) {
        self.delegate = delegate
    }

    func close() {
        delegate?.close()
    }
}

// Wraps any WKNavigationDelegate as AirshipWKNavigationDelegate using ObjC
// message forwarding, so the caller doesn't need to know about AirshipWKNavigationDelegate.
// delegateObj is nonisolated(unsafe) so forwardingTarget/responds can be nonisolated
// (WebKit always calls them on the main thread).
private final class ForwardNavigationDelegateWrapper: NSObject, AirshipWKNavigationDelegate {
    @MainActor weak var delegate: (any WKNavigationDelegate)?
    nonisolated(unsafe) weak var delegateObj: AnyObject?

    @MainActor init(_ delegate: any WKNavigationDelegate) {
        self.delegate = delegate
        self.delegateObj = delegate as AnyObject
    }

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        return super.responds(to: aSelector) || (delegateObj?.responds(to: aSelector) ?? false)
    }

    nonisolated override func forwardingTarget(for aSelector: Selector!) -> Any? {
        return delegateObj
    }
}

/// Airship native bridge for Message Center web views.
@objc
public final class UAMessageCenterNativeBridge: NSObject {

    private let bridge: NativeBridge
    private var forwardNavigationDelegateWrapper: ForwardNavigationDelegateWrapper?
    private var nativeBridgeExtension: MessageCenterNativeBridgeExtension?
    private var nativeBridgeDelegateWrapper: NativeBridgeDelegateWrapper?

    /// The navigation delegate to set on the web view.
    @objc
    @MainActor
    public var navigationDelegate: any WKNavigationDelegate {
        return bridge
    }

    /// Optional delegate for native bridge events such as close.
    @objc
    @MainActor
    public weak var nativeBridgeDelegate: (any UAMessageCenterNativeBridgeDelegate)? {
        get { nativeBridgeDelegateWrapper?.delegate }
        set {
            nativeBridgeDelegateWrapper = newValue.map { NativeBridgeDelegateWrapper($0) }
            bridge.nativeBridgeDelegate = nativeBridgeDelegateWrapper
        }
    }

    /// Optional delegate to receive forwarded navigation callbacks.
    @objc
    @MainActor
    public var forwardNavigationDelegate: (any WKNavigationDelegate)? {
        get { forwardNavigationDelegateWrapper?.delegate }
        set {
            forwardNavigationDelegateWrapper = newValue.map { ForwardNavigationDelegateWrapper($0) }
            bridge.forwardNavigationDelegate = forwardNavigationDelegateWrapper
        }
    }

    @MainActor
    @objc
    public override init() {
        bridge = NativeBridge()
        super.init()
    }

    /// Sets the message and user on the native bridge.
    /// - Parameters:
    ///   - message: The message to display.
    ///   - user: The Message Center user.
    @objc
    @MainActor
    public func setMessage(_ message: UAMessageCenterMessage, user: UAMessageCenterUser) {
        let ext = MessageCenterNativeBridgeExtension(
            message: message.mcMessage,
            user: user.mcUser
        )
        nativeBridgeExtension = ext
        bridge.nativeBridgeExtensionDelegate = ext
    }
}

#endif
