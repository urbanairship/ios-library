/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/**
 * Airship rendering engine.
 * @note For internal use only. :nodoc:
 */
@available(iOS 13.0.0, tvOS 13.0, *)
@objc(UAThomas)
public class Thomas : NSObject {
    private static let decoder = JSONDecoder()
    
    class func decode(_ json: Data) throws -> Layout {
        return try self.decoder.decode(Layout.self, from: json)
    }

    @objc
    public class func validate(data: Data) throws {
        let _ = try decode(data)
    }
    
    @objc
    public class func validate(json: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try validate(data: data)
    }

    @objc
    public class func deferredDisplay(json: Any,
                                      scene: UIWindowScene,
                                      delegate: ThomasDelegate) throws -> () -> Disposable {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try deferredDisplay(data: data, scene: scene, delegate: delegate)
    }
    
    @objc
    public class func deferredDisplay(data: Data,
                                      scene: UIWindowScene,
                                      delegate: ThomasDelegate) throws -> () -> Disposable {
        let layout = try decode(data)
        var dismiss: ((ThomasViewController?) -> Void)?
        var display: ((ThomasViewController) -> Void)?

        switch (layout.presentation) {
        case .banner(_):
            guard let window = Utils.mainWindow(scene: scene) else {
                throw AirshipErrors.error("Failed to find window")
            }
            
            dismiss = { viewController in
                viewController?.dismiss(animated: true) {
                    viewController?.view.removeFromSuperview()
                }
            }
            
            display = { viewController in
                viewController.autoResizeFrame = true
                window.addSubview(viewController.view)
                window.layoutIfNeeded()
            }
            
        case .modal(_):
            var window: UIWindow? = UIWindow(windowScene: scene)
        
            dismiss = { _ in
                window?.windowLevel = .normal
                window?.isHidden = true
                window = nil
            }
            
            display = { viewController in
                window?.windowLevel = .alert
                window?.rootViewController = viewController
                window?.makeKeyAndVisible()
            }
        }
        
        guard let display = display, let dismiss = dismiss else {
            throw AirshipErrors.error("Invalid setup")
        }
        
        var viewController: ThomasViewController?

        let delegate = ThomasDelegateWrapper(delegate) {
            dismiss(viewController)
            viewController = nil
        }
        
        let context = ThomasContext(delegate: delegate)
        viewController = ThomasViewController(rootView: RootView(model: layout.view,
                                                                     presentation: layout.presentation,
                                                                     context: context))
        
        return {
            if let viewController = viewController {
                display(viewController)
            }
            
            return Disposable {
                delegate.onDismiss(buttonIdentifier: nil, cancel: false)
            }
        }
    }
    
    public class func display(_ data: Data,
                              scene: UIWindowScene,
                              delegate: ThomasDelegate) throws -> Disposable {
        return try deferredDisplay(data: data, scene: scene, delegate: delegate)()
    }
}

private class ThomasDelegateWrapper : ThomasDelegate {
    let forwardDelegate: ThomasDelegate
    var isDismissed = false
    var dismiss: (() -> Void)
    
    init(_ forwardDelegate: ThomasDelegate, dismiss: @escaping (() -> Void)) {
        self.forwardDelegate = forwardDelegate
        self.dismiss = dismiss
    }
    
    func onFormResult(formIdentifier: String, formData: [String : Any]) {
        self.forwardDelegate.onFormResult(formIdentifier: formIdentifier, formData: formData)
    }
        
    func onButtonTap(buttonIdentifier: String) {
        self.forwardDelegate.onButtonTap(buttonIdentifier: buttonIdentifier)
    }
    
    func onDismiss(buttonIdentifier: String?, cancel: Bool) {
        if (!self.isDismissed) {
            self.isDismissed = true
            self.forwardDelegate.onDismiss(buttonIdentifier: buttonIdentifier, cancel: cancel)
            dismiss()
        }
    }
    
    func onTimedOut() {
        if (!self.isDismissed) {
            self.isDismissed = true
            self.forwardDelegate.onTimedOut()
            dismiss()
        }
    }

    func onPageView(pagerIdentifier: String, pageIndex: Int, pageCount: Int) {
        self.forwardDelegate.onPageView(pagerIdentifier: pagerIdentifier, pageIndex: pageIndex, pageCount: pageCount)
    }
    
}
