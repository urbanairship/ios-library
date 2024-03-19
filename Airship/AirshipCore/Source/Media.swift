/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Media view.

struct Media: View {

    static let defaultAspectRatio = 16.0 / 9.0
    let model: MediaModel
    let constraints: ViewConstraints
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    private var contentMode: ContentMode {
        var contentMode = ContentMode.fill
        if case .centerInside = self.model.mediaFit {
            contentMode = ContentMode.fit
        }
        return contentMode
    }
    
    var body: some View {
        switch model.mediaType {
        case .image:
            ThomasAsyncImage(
                url: self.model.url,
                imageLoader: thomasEnvironment.imageLoader
            ) { image, imageSize in
                image.fitMedia(
                    mediaFit: self.model.mediaFit,
                    cropPosition: self.model.cropPosition,
                    constraints: constraints,
                    imageSize: imageSize
                )
            } placeholder: {
                AirshipProgressView()
            }
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            .accessible(self.model, hideIfNotSet: true)
        case .video, .youtube:
            #if !os(tvOS) && !os(watchOS)
            MediaWebView(
                url: model.url,
                type: model.mediaType,
                accessibilityLabel: model.contentDescription,
                video: model.video
            )
            .applyIf(self.constraints.width != nil || self.constraints.height != nil) {
                $0.aspectRatio(CGFloat(model.video?.aspectRatio ?? 16.0 / 9.0), contentMode: .fit)
            }
            .constraints(constraints)
            .background(self.model.backgroundColor)
            .border(self.model.border)
            .common(self.model)
            #endif
        }
    }
}

extension Image {

    @ViewBuilder
    func fitMedia(
        mediaFit: MediaFit,
        cropPosition: Position?,
        constraints: ViewConstraints,
        imageSize: CGSize
    ) -> some View {

        let filledInConstraints = filledInConstraints(
            constraints: constraints,
            imageSize: imageSize
        )

        switch mediaFit {
        case .center:
            cropAligned(constraints: filledInConstraints)
        case .fitCrop:
            cropAligned(constraints: filledInConstraints, alignment: cropPositionToAlignment(position: cropPosition))
        case .centerCrop:
            // If we do not have a fixed size in any direction then we should
            // use centerInside instead to match Android
            if isUnbounded(filledInConstraints) {
                centerInside(constraints: filledInConstraints)
            } else {
                cropAligned(constraints: filledInConstraints)
            }
        case .centerInside:
            centerInside(constraints: filledInConstraints)
        }
    }
    
    private func cropPositionToAlignment(position: Position?) -> Alignment {
        guard let position = position else { return .center }
        return Alignment(
            horizontal: position.horizontal.toAlignment(),
            vertical: position.vertical.toAlignment())
    }

    private func cropAligned(constraints: ViewConstraints, alignment: Alignment = .center) -> some View {
        /*
            .scaledToFill() breaks v/hstacks by taking up as much possible space as it can
            instead of sharing it with other elements. Moving the image to an overlay prevents the image from expanding.
         */
        Color.clear
            .overlay(
             GeometryReader { proxy in
                 self.resizable()
                     .scaledToFill()
                     .frame(
                         width: proxy.size.width,
                         height: proxy.size.height,
                         alignment: alignment
                     )
                     .allowsHitTesting(false)
             }
         )
         .constraints(constraints, alignment: alignment, fixedSize: true)
         .clipped()
    }

    private func centerInside(constraints: ViewConstraints) -> some View {
        self.resizable()
            .scaledToFit()
            .constraints(constraints, fixedSize: true)
            .clipped()
    }

    private func filledInConstraints(
        constraints: ViewConstraints,
        imageSize: CGSize
    ) -> ViewConstraints {
        guard imageSize.width != 0, imageSize.height != 0,
            constraints.width == nil || constraints.height == nil
        else {
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

    private func isUnbounded(_ constraints: ViewConstraints) -> Bool {
        if constraints.width != nil && constraints.height != nil {
            return false
        }

        if constraints.width == nil && constraints.height == nil {
            return false
        }

        guard constraints.width == nil else {
            return !constraints.isHorizontalFixedSize
        }
        return !constraints.isVerticalFixedSize
    }
}
