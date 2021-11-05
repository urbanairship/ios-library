/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

@objc(UAThomas)
public class Thomas : NSObject {
    private static let decoder = JSONDecoder()
    
    class func decode(_ json: Data) throws -> Layout {
        return try self.decoder.decode(Layout.self, from: json)
    }
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    @objc
    public class func viewController(payload: Data) throws -> UIViewController {
        let context = ThomasContext(eventHandler: StubbedEventHandler())
        let layout = try decode(payload)
        let viewController = UIHostingController(rootView: RootView(model: layout.view, context: context))
        viewController.view.backgroundColor = .clear
        viewController.modalPresentationStyle = .overCurrentContext;
        return viewController
    }
    
    

    @available(iOS 13.0.0, tvOS 13.0, *)
    private struct RootView : View {
        let model: ViewModel
        let context: ThomasContext

        var body: some View {
            GeometryReader { metrics in
                let constraints = ViewConstraints(width: metrics.size.width,
                                                  height: metrics.size.height)
                ViewFactory.createView(model: model, constraints: constraints)
                    .environmentObject(context)
            }
        }
    }
    
    private class StubbedEventHandler: ThomasEventHandler {
        func onPageView(pagerIdentifier: String, pageIndex: Int, pageCount: Int) {
            AirshipLogger.info("onPageView: \(pagerIdentifier) index: \(pageIndex) count: \(pageCount)")
        }
        
        func onFormResult(formIdentifier: String, formData: FormInputData) {
            let json = try? JSONUtils.string(formData.toDictionary() ?? [:], options: .prettyPrinted)
            AirshipLogger.info("onFormResult: \(formIdentifier): \(json ?? "")")
        }
        
        func onButtonTap(buttonIdentifier: String) {
            AirshipLogger.info("onButtonTap: \(buttonIdentifier)")
        }
        
        func onRunActions(actions: [String : Any]) {
            AirshipLogger.info("onRunActions: \(actions)")
        }
        
        func onDismiss(buttonIdentifier: String) {
            AirshipLogger.info("onDismiss: \(buttonIdentifier)")
        }
        
        func onCancel(buttonIdentifier: String) {
            AirshipLogger.info("onCancel: \(buttonIdentifier)")
        }
    }
}
