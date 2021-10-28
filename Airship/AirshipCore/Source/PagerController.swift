import Foundation
import SwiftUI

@available(iOS 13.0.0, tvOS 13.0, *)
struct PagerController : View {
    let model: PagerControllerModel
    let constraints: ViewConstraints
    @State var pagerState = PagerState()

    var body: some View {
        ViewFactory.createView(model: self.model.view, constraints: constraints)
            .environmentObject(pagerState)
    }
}
