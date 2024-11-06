/* Copyright Airship and Contributors */

import Foundation
public import AirshipCore
public import WebKit

@objc
public class UANativeBridge: NSObject {
    
    private let bridge: NativeBridge
    
    private var _nativeBridgeDelegate: NativeBridgeDelegate?
    /// Delegate to support additional native bridge features such as `close()`.
    @objc
    public var nativeBridgeDelegate: UANativeBridgeDelegate? {
        didSet {
            if let nativeBridgeDelegate {
                
                _nativeBridgeDelegate = UANativeBridgeDelegateWrapper(delegate: nativeBridgeDelegate)
                
                self.bridge.nativeBridgeDelegate = _nativeBridgeDelegate
            } else {
                self.bridge.nativeBridgeDelegate = nil
            }
        }
    }

    
    private var _forwardNavigationDelegate: AirshipWKNavigationDelegate?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public var forwardNavigationDelegate: UANavigationDelegate?
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
    
    private var _javaScriptCommandDelegate: JavaScriptCommandDelegate?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public var javaScriptCommandDelegate: UAJavaScriptCommandDelegate?
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
    
    
    private var _nativeBridgeExtensionDelegate: NativeBridgeExtensionDelegate?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public var nativeBridgeExtensionDelegate: UANativeBridgeExtensionDelegate?
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
    public override init() {
        self.bridge = NativeBridge()
    }
    
}

@objc
public protocol UANavigationDelegate: WKNavigationDelegate {
    @objc optional func closeWindow(_ animated: Bool)
}

public class UANavigationDelegateWrapper: NSObject, AirshipWKNavigationDelegate {
    private let delegate: UANavigationDelegate
    
    init(delegate: UANavigationDelegate) {
        self.delegate = delegate
    }
}
