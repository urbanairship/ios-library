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
            AirshipAsyncImage(url: self.model.url) { image, imageSize in
                image
                    .fitMedia(mediaFit:self.model.mediaFit, constraints: constraints, imageSize: imageSize)
            } placeholder: {
                AirshipProgressView()
            }
            .constraints(constraints)
            .background(model.backgroundColor)
            .border(model.border)
            .viewAccessibility(label: self.model.contentDescription)
        case .video, .youtube:
#if !os(tvOS)
            MediaWebView(url: model.url, type: model.mediaType, accessibilityLabel: model.contentDescription)
                .constraints(constraints)
                .applyIf(self.constraints.width != nil || self.constraints.height != nil) {
                    $0.aspectRatio(16.0/9.0, contentMode: .fit)
                }
                .background(model.backgroundColor)
                .border(model.border)
                
#endif
        }
    }
}

@available(iOS 13.0.0, tvOS 13.0.0, *)
extension Image {
    
    @ViewBuilder
    func fitMedia(mediaFit: MediaFit,
                  constraints: ViewConstraints,
                  imageSize: CGSize) -> some View {
        
        switch mediaFit {
        case .center:
            center(constraints: constraints)
        case .centerCrop:
            centerCrop(constraints: constraints, imageSize: imageSize)
        case .centerInside:
            centerInside(constraints: constraints)
        }
    }
    
    private func center(constraints: ViewConstraints) -> some View {
        self
            .constraints(constraints)
            .clipped()
    }
    
    private func centerCrop(constraints: ViewConstraints, imageSize: CGSize) -> some View {
        /*
         .scaledToFill() breaks v/hstacks by taking up as much possible space as it can
         instead of sharing it with other elements. Moving the image to an overlay prevents the image from expanding.
         */
        Color.clear
            .overlay(
                GeometryReader { proxy in
                    self.resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .allowsHitTesting(false)
                })
            .constraints(centerCropConstraints(constraints: constraints, imageSize: imageSize))
            .clipped()
    }
    
    private func centerInside(constraints: ViewConstraints) -> some View {
        self
            .resizable()
            .scaledToFit()
            .constraints(constraints)
            .clipped()
    }
    
    private func centerCropConstraints(constraints: ViewConstraints, imageSize: CGSize) -> ViewConstraints {
        guard imageSize.width != 0, imageSize.height != 0, constraints.width == nil || constraints.height == nil else {
            return constraints
        }
        
        // Fill in any missing constraints
        var modifiedConstraints = constraints
        if let height = constraints.height {
            modifiedConstraints.width = modifiedConstraints.width ?? ((imageSize.width / imageSize.height) * height)
        } else if let width = constraints.width {
            modifiedConstraints.height = modifiedConstraints.height ?? ((imageSize.height / imageSize.width) * width)
        }
        return modifiedConstraints
    }
}
