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
    public class func viewController(payload: Data, eventHandler: ThomasEventHandler) throws -> UIViewController {
        let context = ThomasContext(eventHandler: eventHandler)
        let layout = try decode(payload)
        let viewController = UIHostingController(rootView: RootView(model: layout.view, presentation: layout.presentation, context: context))
        viewController.view.backgroundColor = .clear
        viewController.modalPresentationStyle = .overCurrentContext;
        return viewController
    }
    
    @available(iOS 13.0.0, tvOS 13.0, *)
    private struct RootView : View {
        let model: ViewModel
        let presentation: PresentationModel
        let context: ThomasContext
        @State var orientationState: OrientationState = OrientationState(orientation: RootView.resolveOrientation())

        var body: some View {
            GeometryReader { metrics in
                let constraints = ViewConstraints(contentWidth: metrics.size.width,
                                                  contentHeight: metrics.size.height,
                                                  frameWidth: metrics.size.width,
                                                  frameHeight: metrics.size.height)
                
                switch presentation {
                case .banner(_):
                    //TODO: Add banner view modifier and use it
                    ViewFactory.createView(model: model, constraints: constraints)
                        .environmentObject(context)
                        .environmentObject(orientationState)
                case .modal(let modalModel):
                    ModalView(model: modalModel, constraints: constraints, rootViewModel: model)
                        .environmentObject(context)
                        .environmentObject(orientationState)
                }
            }
            .onAppear {
                self.orientationState.orientation = RootView.resolveOrientation()
            }
            #if !os(tvOS)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                self.orientationState.orientation = RootView.resolveOrientation()
            }
            #endif
        }
        
        private static func resolveOrientation() -> Orientation? {
            guard let scene = UIApplication.shared.windows.first?.windowScene else { return nil }
            #if os(tvOS)
            return .landscape
            #else
            if (scene.interfaceOrientation.isLandscape) {
                return .landscape
            } else if (scene.interfaceOrientation.isPortrait) {
                return .portrait
            }
            return nil
            #endif
        }
    }
    
}
