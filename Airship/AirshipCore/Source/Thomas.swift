/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/**
 * Airship rendering engine.
 * @note For internal use only. :nodoc:
 */
@available(iOS 13.0.0, tvOS 13.0, *)
@objc(UAThomas)
public class Thomas: NSObject {
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
                                      extensions: ThomasExtensions? = nil,
                                      delegate: ThomasDelegate) throws -> () -> Disposable {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try deferredDisplay(data: data, scene: scene, extensions: extensions, delegate: delegate)
    }
    
    @objc
    @discardableResult
    public class func deferredDisplay(data: Data,
                                      scene: UIWindowScene,
                                      extensions: ThomasExtensions? = nil,
                                      delegate: ThomasDelegate) throws -> () -> Disposable {
        let layout = try decode(data)
        switch (layout.presentation) {
        case .banner(let presentation):
            return try bannerDisplay(presentation, scene: scene, layout: layout, extensions: extensions, delegate: delegate)
        case .modal(let presentation):
            return try modalDisplay(presentation, scene: scene, layout: layout, extensions: extensions, delegate: delegate)
        }
    }
    
    @discardableResult
    public class func display(_ data: Data,
                              scene: UIWindowScene,
                              extensions: ThomasExtensions? = nil,
                              delegate: ThomasDelegate) throws -> Disposable {
        return try deferredDisplay(data: data,
                                   scene: scene,
                                   extensions: extensions,
                                   delegate: delegate)()
    }
    
    private class func bannerDisplay(_ presentation: BannerPresentationModel,
                                     scene: UIWindowScene,
                                     layout: Layout,
                                     extensions: ThomasExtensions?,
                                     delegate: ThomasDelegate) throws -> () -> Disposable {
        
        guard let window = Utils.mainWindow(scene: scene), window.rootViewController != nil else {
            throw AirshipErrors.error("Failed to find window")
        }
        
        var viewController: ThomasViewController<BannerView>?

        let dismissController = {
            viewController?.view.removeFromSuperview()
            viewController = nil
        }
    
        let environment = ThomasEnvironment(delegate: delegate, extensions: extensions) {
            if let dismissable = viewController?.rootView.dismiss {
                dismissable(dismissController)
            } else {
                dismissController()
            }
        }
        let rootView = BannerView(presentation: presentation,
                                  layout: layout,
                                  thomasEnvironment: environment)
        viewController = ThomasViewController<BannerView>(rootView: rootView)
        
        return {
            if let viewController = viewController, let rootController = window.rootViewController {
                rootController.addChild(viewController)
                viewController.didMove(toParent: rootController)
                rootController.view.addSubview(viewController.view)
                viewController.view.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    viewController.view.topAnchor.constraint(equalTo: rootController.view.topAnchor),
                    viewController.view.leadingAnchor.constraint(equalTo: rootController.view.leadingAnchor),
                    viewController.view.trailingAnchor.constraint(equalTo: rootController.view.trailingAnchor),
                    viewController.view.bottomAnchor.constraint(equalTo: rootController.view.bottomAnchor),
                ])
            }
            
            return Disposable {
                environment.dismiss()
            }
        }
    }
    
    private class func modalDisplay(_ presentation: ModalPresentationModel,
                                    scene: UIWindowScene,
                                    layout: Layout,
                                    extensions: ThomasExtensions?,
                                    delegate: ThomasDelegate) throws -> () -> Disposable {
        
        var window: UIWindow? = UIWindow(windowScene: scene)
        var viewController: ThomasViewController<ModalView>?
        viewController?.modalPresentationStyle = .currentContext
    
    
        let environment = ThomasEnvironment(delegate: delegate, extensions: extensions) {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }
        
        let rootView = ModalView(presentation: presentation,
                                 layout: layout,
                                 thomasEnvironment: environment)
        viewController = ThomasViewController<ModalView>(rootView: rootView)
        window?.rootViewController = viewController

        return {
            window?.windowLevel = .alert
            window?.makeKeyAndVisible()
            
            return Disposable {
                environment.dismiss()
            }
        }
    }
}

/**
 * Airship rendering engine extensions.
 * @note For internal use only. :nodoc:
 */
@available(iOS 13.0.0, tvOS 13.0, *)
@objc(UAThomasExtensions)
public class ThomasExtensions: NSObject {
    #if !os(tvOS)
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    #endif

    #if !os(tvOS)
    @objc
    public init(nativeBridgeExtension: NativeBridgeExtensionDelegate?) {
        self.nativeBridgeExtension = nativeBridgeExtension
    }
    #endif
    
}
