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
            AirshipAsyncImage(url: self.model.url) { image in
                image
                    .fitMedia(mediaFit: self.model.mediaFit, width: self.constraints.width, height: self.constraints.height)
            } placeholder: {
                AirshipProgressView()
            }
            .background(model.backgroundColor)
            .border(model.border)
            .constraints(constraints)
            .viewAccessibility(label: self.model.contentDescription)
        case .video, .youtube:
#if !os(tvOS)
            MediaWebView(url: model.url, type: model.mediaType, accessibilityLabel: model.contentDescription)
                .background(model.backgroundColor)
                .border(model.border)
                .constraints(constraints)
                .applyIf(self.constraints.width != nil || self.constraints.height != nil) {
                    $0.aspectRatio(16.0/9.0, contentMode: .fit)
                }
#endif
        }
    }
}
