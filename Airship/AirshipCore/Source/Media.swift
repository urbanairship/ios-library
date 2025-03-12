/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

/// Media view.

struct Media: View {
    @EnvironmentObject var thomasEnvironment: ThomasEnvironment

    let info: ThomasViewInfo.Media
    let constraints: ViewConstraints
    @State
    private var mediaID: UUID = UUID()
    private let defaultAspectRatio = 16.0 / 9.0
    @EnvironmentObject var pagerState: PagerState
    @Environment(\.pageIdentifier) var pageIdentifier

    var videoAspectRatio: CGFloat {
        CGFloat(self.info.properties.video?.aspectRatio ?? defaultAspectRatio)
    }

    var body: some View {
        switch self.info.properties.mediaType {
        case .image:
            ThomasAsyncImage(
                url: self.info.properties.url,
                imageLoader: thomasEnvironment.imageLoader
            ) { image, imageSize in
                image.fitMedia(
                    mediaFit: self.info.properties.mediaFit,
                    cropPosition: self.info.properties.cropPosition,
                    constraints: constraints,
                    imageSize: imageSize
                ).allowsHitTesting(false)
            } placeholder: {
                AirshipProgressView()
            }
            .constraints(constraints)
            .thomasCommon(self.info)
            .accessible(self.info.accessible, hideIfDescriptionIsMissing: true)
        case .video, .youtube:
            #if !os(tvOS) && !os(watchOS)
            MediaWebView(info: self.info) {
                pagerState.setMediaReady(
                    pageId: pageIdentifier ?? "",
                    id: mediaID,
                    isReady: true
                )
            }
            .onAppear {
                pagerState.registerMedia(pageId: pageIdentifier ?? "", id: mediaID)
            }
            .airshipApplyIf(self.constraints.width == nil || self.constraints.height == nil) {
                $0.aspectRatio(videoAspectRatio, contentMode: ContentMode.fit)
            }
            .constraints(constraints)
            .thomasCommon(self.info)
            #endif
        }
    }
}

extension Image {

    @ViewBuilder
    @MainActor
    func fitMedia(
        mediaFit: ThomasMediaFit,
        cropPosition: ThomasPosition?,
        constraints: ViewConstraints,
        imageSize: CGSize
    ) -> some View {
        switch mediaFit {
        case .center:
            cropAligned(constraints: constraints, imageSize: imageSize)
        case .fitCrop:
            cropAligned(constraints: constraints, imageSize: imageSize, alignment: cropPosition?.alignment ?? .center)
        case .centerCrop:
            cropAligned(constraints: constraints, imageSize: imageSize)
        case .centerInside:
            centerInside(constraints: constraints)
        }
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
    @MainActor
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

    @MainActor
    private func centerInside(constraints: ViewConstraints) -> some View {
        self.resizable()
            .scaledToFit()
            .constraints(constraints)
            .clipped()
    }
}
