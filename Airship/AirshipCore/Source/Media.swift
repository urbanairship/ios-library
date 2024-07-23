/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Media view.

struct Media: View {
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    let model: MediaModel
    let constraints: ViewConstraints
    @State
    private var mediaID: UUID = UUID()
    private let defaultAspectRatio = 16.0 / 9.0
    @EnvironmentObject var pagerState: PagerState
    @Environment(\.pageIndex) var pageIndex
 

    private var contentMode: ContentMode {
        var contentMode = ContentMode.fill

        /// Fit container if undefined size on x and y axes, otherwise fill and crop content on major axis to maintain aspect ratio
        if self.model.mediaFit == .centerInside && Self.isUnbounded(constraints) {
            contentMode = ContentMode.fit
        }

        return contentMode
    }

    fileprivate static func isUnbounded(_ constraints: ViewConstraints) -> Bool {
        if constraints.width != nil && constraints.height != nil {
            return false
        }

        if constraints.width == nil && constraints.height == nil {
            return true
        }

        guard constraints.width != nil else {
            return !constraints.isHorizontalFixedSize
        }
        return !constraints.isVerticalFixedSize
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
            ) {
                pagerState.setMediaReady(pageIndex: pageIndex, id: mediaID, isReady: true)
            }
            .onAppear {
                pagerState.registerMedia(pageIndex: pageIndex, id: mediaID)
            }
            .applyIf(self.constraints.width != nil || self.constraints.height != nil) {
                $0.aspectRatio(CGFloat(model.video?.aspectRatio ?? defaultAspectRatio), contentMode: self.contentMode)
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


        switch mediaFit {
        case .center:
            cropAligned(constraints: constraints)
        case .fitCrop:
            cropAligned(constraints: constraints, alignment: cropPositionToAlignment(position: cropPosition))
        case .centerCrop:
            // If we do not have a fixed size in any direction then we should
            // use centerInside instead to match Android
            if Media.isUnbounded(constraints) {
                centerInside(constraints: constraints)
            } else {
                cropAligned(constraints: constraints)
            }
        case .centerInside:
            centerInside(constraints: constraints)
        }
    }
    
    private func cropPositionToAlignment(position: Position?) -> Alignment {
        guard let position = position else { return .center }
        return Alignment(
            horizontal: position.horizontal.toAlignment(),
            vertical: position.vertical.toAlignment()
        )
    }

    private func cropAligned(constraints: ViewConstraints, alignment: Alignment = .center) -> some View {
           self.resizable()
            .scaledToFill()
            .constraints(constraints, alignment: alignment)
            .clipped()
    }

    private func centerInside(constraints: ViewConstraints) -> some View {
        self.resizable()
            .scaledToFit()
            .constraints(constraints)
            .clipped()
    }
}
