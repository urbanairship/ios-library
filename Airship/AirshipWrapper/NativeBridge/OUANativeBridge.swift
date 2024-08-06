/* Copyright Airship and Contributors */

import Foundation
import AirshipCore
import WebKit

@objc(OUANativeBridge)
public class OUANativeBridge: NSObject {
    
    private let bridge: NativeBridge
    
    private var _nativeBridgeDelegate: NativeBridgeDelegate?
    /// Delegate to support additional native bridge features such as `close()`.
    @objc
    public var nativeBridgeDelegate: OUANativeBridgeDelegate? {
        didSet {
            if let nativeBridgeDelegate {
                
                _nativeBridgeDelegate = OUANativeBridgeDelegateWrapper(delegate: nativeBridgeDelegate)
                
                self.bridge.nativeBridgeDelegate = _nativeBridgeDelegate
            } else {
                self.bridge.nativeBridgeDelegate = nil
            }
        }
    }

    
    private var _forwardNavigationDelegate: UANavigationDelegate?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public var forwardNavigationDelegate: OUANavigationDelegate?
 {
        didSet {
            if let forwardNavigationDelegate {
                _forwardNavigationDelegate = OUANavigationDelegateWrapper(delegate: forwardNavigationDelegate)
                
                self.bridge.forwardNavigationDelegate = _forwardNavigationDelegate
            } else {
                self.bridge.forwardNavigationDelegate = nil
            }
        }
    }
    
    private var _javaScriptCommandDelegate: JavaScriptCommandDelegate?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public var javaScriptCommandDelegate: OUAJavaScriptCommandDelegate?
 {
        didSet {
            if let javaScriptCommandDelegate {
                _javaScriptCommandDelegate = OUAJavaScriptCommandDelegateWrapper(delegate: javaScriptCommandDelegate)
                
                self.bridge.javaScriptCommandDelegate = _javaScriptCommandDelegate
            } else {
                self.bridge.javaScriptCommandDelegate = nil
            }
        }
    }
    
    
    private var _nativeBridgeExtensionDelegate: NativeBridgeExtensionDelegate?
    /// Optional delegate to forward any WKNavigationDelegate calls.
    @objc
    public var nativeBridgeExtensionDelegate: OUANativeBridgeExtensionDelegate?
 {
        didSet {
            if let nativeBridgeExtensionDelegate {
                _nativeBridgeExtensionDelegate = OUANativeBridgeExtensionDelegateWrapper(delegate: nativeBridgeExtensionDelegate)
                
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
public protocol OUANavigationDelegate: WKNavigationDelegate {
    @objc optional func closeWindow(_ animated: Bool)
}

public class OUANavigationDelegateWrapper: NSObject, UANavigationDelegate {
    private let delegate: OUANavigationDelegate
    
    init(delegate: OUANavigationDelegate) {
        self.delegate = delegate
    }
}
