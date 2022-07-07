/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Airship rendering engine.
/// - Note: for internal use only.  :nodoc:
@available(iOS 13.0.0, tvOS 13.0, *)
@objc(UAThomas)
public class Thomas: NSObject {
    
    private static let decoder = JSONDecoder()
    static let minLayoutVersion = 1
    static let maxLayoutVersion = 2
    
    class func decode(_ json: Data) throws -> Layout {
        let layout = try self.decoder.decode(Layout.self, from: json)
        return layout
    }
    
    @objc
    public class func validate(data: Data) throws {
        let layout = try decode(data)

        guard layout.version >= minLayoutVersion && layout.version <= maxLayoutVersion else {
            throw AirshipErrors.error("Unable to process layout with version \(layout.version)")
        }

        try layout.validate()
    }

    @objc
    public class func validate(json: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        try validate(data: data)
    }
    

    @objc
    public class func urls(json: Any) throws -> [URLInfo]  {
        let data = try JSONSerialization.data(withJSONObject: json, options: [])
        return try decode(data).urlInfos()
    }

    #if !os(watchOS)
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
        
        var viewController: ThomasBannerViewController?

        let dismissController = {
            viewController?.view.removeFromSuperview()
            viewController = nil
        }
    
        let options = ThomasViewControllerOptions()
        let environment = ThomasEnvironment(delegate: delegate, extensions: extensions) {
            if let dismissable = viewController?.rootView.dismiss {
                dismissable(dismissController)
            } else {
                dismissController()
            }
        }
        let rootView = BannerView(viewControllerOptions: options, presentation: presentation,
                                  layout: layout,
                                  thomasEnvironment: environment)
        viewController = ThomasBannerViewController(rootView: rootView, options: options)
        
        return {
            if let viewController = viewController, let rootController = window.rootViewController {
                rootController.addChild(viewController)
                viewController.didMove(toParent: rootController)
                rootController.view.addSubview(viewController.view)
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
        var viewController: ThomasModalViewController?
        
        let options = ThomasViewControllerOptions()
        let environment = ThomasEnvironment(delegate: delegate, extensions: extensions) {
            window?.windowLevel = .normal
            window?.isHidden = true
            window = nil
        }
        
        let rootView = ModalView(presentation: presentation,
                                 layout: layout,
                                 thomasEnvironment: environment,
                                 viewControllerOptions: options)
        viewController = ThomasModalViewController(rootView: rootView, options: options)
        viewController?.modalPresentationStyle = .currentContext
        window?.rootViewController = viewController
        
        return {
            window?.windowLevel = .alert
            window?.makeKeyAndVisible()
            
            return Disposable {
                environment.dismiss()
            }
        }
    }
#endif
}

/// Airship rendering engine extensions.
/// - Note: for internal use only.  :nodoc:
@available(iOS 13.0.0, tvOS 13.0, *)
@objc(UAThomasExtensions)
public class ThomasExtensions: NSObject {
    
    
    #if !os(tvOS) && !os(watchOS)
    let nativeBridgeExtension: NativeBridgeExtensionDelegate?
    #endif
    
    let imageProvider: ImageProvider?

    #if os(tvOS) || os(watchOS)
    @objc
    public init(imageProvider: ImageProvider? = nil) {
        self.imageProvider = imageProvider;
    }
    #else
    @objc
    public init(nativeBridgeExtension: NativeBridgeExtensionDelegate? = nil,
                imageProvider: ImageProvider? = nil) {
        self.nativeBridgeExtension = nativeBridgeExtension
        self.imageProvider = imageProvider;
    }
    #endif
}

@objc
public enum UrlTypes : Int {
    case image
    case video
    case web
}
