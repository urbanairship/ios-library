/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Media view.
@available(iOS 13.0.0, tvOS 13.0, *)
struct Media : View {
    
    let model: MediaModel
    let constraints: ViewConstraints
    
    var body: some View {
        switch model.mediaType {
        case .image:
            ImageView(url: model.url)
                .background(model.backgroundColor)
                .border(model.border)
                .constraints(constraints)

        case .video, .youtube:
#if !os(tvOS)
            MediaWebView(url: model.url, type: model.mediaType)
                .background(model.backgroundColor)
                .border(model.border)
                .constraints(constraints)
#endif
        }
    }
}
