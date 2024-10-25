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
                ).allowsHitTesting(false)
            } placeholder: {
                AirshipProgressView()
            }
            .constraints(constraints)
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
            .common(self.model)
            .accessible(self.model, hideIfNotSet: true)
        case .video, .youtube:
            #if !os(tvOS) && !os(watchOS)
            MediaWebView(
                model: model
            ) {
                pagerState.setMediaReady(pageIndex: pageIndex, id: mediaID, isReady: true)
            }
            .onAppear {
                pagerState.registerMedia(pageIndex: pageIndex, id: mediaID)
            }
            .applyIf(self.constraints.width == nil || self.constraints.height == nil) {
                $0.aspectRatio(CGFloat(model.video?.aspectRatio ?? defaultAspectRatio), contentMode: .fit)
            }
            .constraints(constraints)
            .background(
                color: self.model.backgroundColor,
                border: self.model.border
            )
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
            cropAligned(constraints: constraints, imageSize: imageSize)
        case .fitCrop:
            cropAligned(constraints: constraints, imageSize: imageSize, alignment: cropPositionToAlignment(position: cropPosition))
        case .centerCrop:
            cropAligned(constraints: constraints, imageSize: imageSize)
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

    private func shouldCenterInside(constraints: ViewConstraints, imageSize: CGSize) -> Bool {
        guard constraints.height == nil || constraints.width == nil else {
            return false
        }

        let aspectRatio = imageSize.width/imageSize.height

        if let height = constraints.height, let maxWidth = constraints.maxWidth {
            let fitWidth = height * aspectRatio
            return fitWidth <= maxWidth
        }

        if let width = constraints.width, let maxHeight = constraints.maxHeight {
            let fitHeight = width / aspectRatio
            return fitHeight <= maxHeight
        }

        return false
    }

    @ViewBuilder
    private func cropAligned(constraints: ViewConstraints, imageSize: CGSize, alignment: Alignment = .center) -> some View {
        // If we have an auto bound constraint and we can fit the image then centerInside
        if shouldCenterInside(constraints: constraints, imageSize: imageSize) {
            centerInside(constraints: constraints)
        } else {
            self.resizable()
             .scaledToFill()
             .constraints(constraints, alignment: alignment)
             .frame(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight)
             .clipped()
        }
    }

    private func centerInside(constraints: ViewConstraints) -> some View {
        self.resizable()
            .scaledToFit()
            .constraints(constraints)
            .clipped()
    }
}
