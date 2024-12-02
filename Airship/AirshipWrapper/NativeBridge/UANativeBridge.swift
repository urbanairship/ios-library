/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore
public import WebKit

@objc
public class UANativeBridge: NSObject {
    
    private let bridge: NativeBridge
    
    private var _nativeBridgeDelegate: (any NativeBridgeDelegate)?
    /// Delegate to support additional native bridge features such as `close()`.
    @objc
    @MainActor
    public var nativeBridgeDelegate: (any UANativeBridgeDelegate)? {
        didSet {
            if let nativeBridgeDelegate {
                
                _nativeBridgeDelegate = UANativeBridgeDelegateWrapper(delegate: nativeBridgeDelegate)
                
                self.bridge.nativeBridgeDelegate = _nativeBridgeDelegate
            } else {
                self.bridge.nativeBridgeDelegate = nil
            }
        }
    }

    
    private var _forwardNavigationDelegate: (any AirshipWKNavigationDelegate)?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    @MainActor
    public var forwardNavigationDelegate: (any UANavigationDelegate)?
 {
        didSet {
            if let forwardNavigationDelegate {
                _forwardNavigationDelegate = UANavigationDelegateWrapper(delegate: forwardNavigationDelegate)
                
                self.bridge.forwardNavigationDelegate = _forwardNavigationDelegate
            } else {
                self.bridge.forwardNavigationDelegate = nil
            }
        }
    }
    
    private var _javaScriptCommandDelegate: (any JavaScriptCommandDelegate)?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    @MainActor
    public var javaScriptCommandDelegate: (any UAJavaScriptCommandDelegate)?
 {
        didSet {
            if let javaScriptCommandDelegate {
                _javaScriptCommandDelegate = UAJavaScriptCommandDelegateWrapper(delegate: javaScriptCommandDelegate)
                
                self.bridge.javaScriptCommandDelegate = _javaScriptCommandDelegate
            } else {
                self.bridge.javaScriptCommandDelegate = nil
            }
        }
    }
    
    
    private var _nativeBridgeExtensionDelegate: (any NativeBridgeExtensionDelegate)?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    @MainActor
    public var nativeBridgeExtensionDelegate: (any UANativeBridgeExtensionDelegate)?
 {
        didSet {
            if let nativeBridgeExtensionDelegate {
                _nativeBridgeExtensionDelegate = UANativeBridgeExtensionDelegateWrapper(delegate: nativeBridgeExtensionDelegate)
                
                self.bridge.nativeBridgeExtensionDelegate = _nativeBridgeExtensionDelegate
            } else {
                self.bridge.nativeBridgeExtensionDelegate = nil
            }
        }
    }
    
    /// NativeBridge initializer.
    @objc
    @MainActor
    public override init() {
        self.bridge = NativeBridge()
    }
    
}

@objc
public protocol UANavigationDelegate: WKNavigationDelegate {
    @objc optional func closeWindow(_ animated: Bool)
}

public class UANavigationDelegateWrapper: NSObject, AirshipWKNavigationDelegate {
    private let delegate: any UANavigationDelegate
    
    init(delegate: any UANavigationDelegate) {
        self.delegate = delegate
    }
}
