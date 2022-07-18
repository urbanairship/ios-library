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
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            .accessible(self.model)
        case .video, .youtube:
#if !os(tvOS) && !os(watchOS)
            MediaWebView(url: model.url,
                         type: model.mediaType,
                         accessibilityLabel: model.contentDescription)
                .constraints(constraints)
                .applyIf(self.constraints.width != nil || self.constraints.height != nil) {
                    $0.aspectRatio(16.0/9.0, contentMode: .fit)
                }
                .background(self.model.backgroundColor)
                .border(self.model.border)
                .common(self.model)
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

        let filledInConstraints = filledInConstraints(constraints: constraints, imageSize: imageSize)

        switch mediaFit {
        case .center:
            center(constraints: filledInConstraints)
        case .centerCrop:
            // If we do not have a fixed size in any direction then we should
            // use centerInside instead to match Android
            if isUnbounded(constraints) {
                centerInside(constraints: filledInConstraints)
            } else {
                centerCrop(constraints: filledInConstraints)
            }
        case .centerInside:
            centerInside(constraints: filledInConstraints)
        }
    }
    
    private func center(constraints: ViewConstraints) -> some View {
        self.constraints(constraints, fixedSize: true)
            .clipped()
    }
    
    private func centerCrop(constraints: ViewConstraints) -> some View {

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
            .constraints(constraints, fixedSize: true)
            .clipped()
    }
    
    private func centerInside(constraints: ViewConstraints) -> some View {
        self.resizable()
            .scaledToFit()
            .constraints(constraints, fixedSize: true)
            .clipped()
    }

    private func filledInConstraints(constraints: ViewConstraints, imageSize: CGSize) -> ViewConstraints {
        guard imageSize.width != 0, imageSize.height != 0, constraints.width == nil || constraints.height == nil else {
            return constraints
        }
        
        // Fill in any missing constraints
        var modifiedConstraints = constraints
        if let height = constraints.height {
            modifiedConstraints.width = modifiedConstraints.width ?? ((imageSize.width / imageSize.height) * height)
            modifiedConstraints.isHorizontalFixedSize = true
        } else if let width = constraints.width {
            modifiedConstraints.height = modifiedConstraints.height ?? ((imageSize.height / imageSize.width) * width)
            modifiedConstraints.isVerticalFixedSize = true
        }
        return modifiedConstraints
    }

    private func isUnbounded(_ constraints: ViewConstraints)  -> Bool {
        if (constraints.width != nil && constraints.height != nil) {
            return false
        }

        if (constraints.width == nil && constraints.height == nil) {
            return false
        }

        if (constraints.width == nil) {
            return !constraints.isVerticalFixedSize
        } else {
            return !constraints.isHorizontalFixedSize
        }
    }
}
