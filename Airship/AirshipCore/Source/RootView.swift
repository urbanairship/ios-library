import SwiftUI
@available(iOS 13.0.0, tvOS 13.0, *)
struct RootView : View {
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
            case .banner(let bannerModel):
                BannerView(model: bannerModel, constraints: constraints, rootViewModel: model, offset: constraints.frameHeight ?? 0.0)
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
