/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@objc(UAThomas)
public class Thomas : NSObject {
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    @objc
    public class func viewController(payload: Data) throws -> UIViewController {
        let layout = try LayoutDecoder.decode(payload)
        let viewController = UIHostingController(rootView: RootView(model: layout.layout))
        viewController.view.backgroundColor = .clear
        viewController.modalPresentationStyle = .overCurrentContext;
        return viewController
    }
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    private struct RootView : View {
        let model: BaseViewModel
        
        var body: some View {
            GeometryReader { metrics in
                let constraints = ViewConstraints(minWidth: 0,
                                                  width: metrics.size.width,
                                                  minHeight: 0,
                                                  height: metrics.size.height)
                
                ViewFactory.createView(model: model, constraints: constraints)
            }
        }
    }
}
