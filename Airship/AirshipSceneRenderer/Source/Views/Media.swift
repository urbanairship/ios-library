/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import AVFoundation
@_spi(AirshipInternal) import AirshipBasement

/// Media view.

struct Media: View {
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState

    private let info: ThomasViewInfo.Media
    private let constraints: ViewConstraints
    @State
    private var mediaID: UUID = UUID()
    private let defaultAspectRatio: Double = 16.0 / 9.0
    @EnvironmentObject private var pagerState: PagerState
    @Environment(\.pageIdentifier) private var pageIdentifier
    @Environment(\.colorScheme) private var colorScheme

    private var resolvedURL: String {
        ThomasPropertyOverride.resolveRequired(
            state: thomasState,
            overrides: info.overrides?.url,
            defaultValue: info.properties.url
        )
    }

    private var resolvedURLSelectors: [ThomasMediaUrlSelector]? {
        ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: info.overrides?.urlSelectors,
            defaultValue: info.properties.urlSelectors
        )
    }

    init(info: ThomasViewInfo.Media, constraints: ViewConstraints) {
        self.info = info
        self.constraints = constraints
    }

    private var videoAspectRatio: CGFloat {
        CGFloat(self.info.properties.video?.aspectRatio ?? defaultAspectRatio)
    }

    var body: some View {
        switch self.info.properties.mediaType {
        case .image:
            ThomasAsyncImage(
                url: resolvedURLSelectors?.resolve(colorScheme: colorScheme) ?? resolvedURL,
                loadImage: thomasEnvironment.imageLoader.load
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
            .accessible(
                self.info.accessible,
                associatedLabel: nil,
                hideIfDescriptionIsMissing: true
            )
        case .video:
#if !os(watchOS) && !os(macOS)
            VideoMediaNativeView(
                info: self.info,
                videoIdentifier: self.info.properties.identifier ?? mediaID.uuidString,
                constraints: constraints,
                videoAspectRatio: videoAspectRatio,
                onMediaReady: {
                    pagerState.setMediaReady(
                        pageId: pageIdentifier ?? "",
                        id: mediaID,
                        isReady: true
                    )
                }
            )
            .onAppear {
                pagerState.registerMedia(pageId: pageIdentifier ?? "", id: mediaID)
            }
            .thomasCommon(self.info)
#endif
        case .youtube, .vimeo:
#if !os(tvOS) && !os(watchOS)
            VideoMediaWebView(
                info: self.info,
                videoIdentifier: self.info.properties.identifier ?? mediaID.uuidString
            ) {
                pagerState.setMediaReady(
                    pageId: pageIdentifier ?? "",
                    id: mediaID,
                    isReady: true
                )
            }
            .airshipApplyIf(self.constraints.width == nil || self.constraints.height == nil) {
                $0.aspectRatio(videoAspectRatio, contentMode: ContentMode.fit)
            }
            .constraints(constraints)
            .onAppear {
                pagerState.registerMedia(pageId: pageIdentifier ?? "", id: mediaID)
            }
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
        let aspectRatio = imageSize.height > 0 ? imageSize.width/imageSize.height : 1.0
        return shouldShowMediaWhole(constraints: constraints, aspectRatio: aspectRatio)
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
                // Bounds the fill on an axis with no length of its own, so `limit(on:)` rather
                // than the raw maximum — the same reading the crop decision above uses. A measured
                // maximum is the siblings' extent handed back, and clamping to it is what the
                // decision declined to crop for.
                //
                // Carries the alignment because on an `auto` axis this is the frame that crops.
                // The one above takes its lengths from the declared size, so an auto axis leaves it
                // nil there and it sizes to the filled image instead — the image exactly fills it,
                // and an alignment with no slack to distribute does nothing. The overflow is still
                // ahead of it, and this is where it gets cut: left to its default, a `fit_crop`
                // image declared `width: auto` was centered whatever `position` asked for.
                .frame(
                    maxWidth: constraints.limit(on: .horizontal),
                    maxHeight: constraints.limit(on: .vertical),
                    alignment: alignment
                )
                .clipped()
        }
    }

    @MainActor
    private func centerInside(constraints: ViewConstraints) -> some View {
        self.resizable()
            .scaledToFit()
            .constraints(constraints)
            .ignoresSafeArea()
            .clipped()
    }
}

// Basically mirror the Image.fitMedia functionality
extension View {
    @ViewBuilder
    @MainActor
    func fitVideo(
        mediaFit: ThomasMediaFit,
        cropPosition: ThomasPosition?,
        constraints: ViewConstraints,
        videoAspectRatio: CGFloat
    ) -> some View {
        switch mediaFit {
        case .center:
            cropAlignedVideo(constraints: constraints, videoAspectRatio: videoAspectRatio)
        case .fitCrop:
            cropAlignedVideo(constraints: constraints, videoAspectRatio: videoAspectRatio, alignment: cropPosition?.alignment ?? .center)
        case .centerCrop:
            cropAlignedVideo(constraints: constraints, videoAspectRatio: videoAspectRatio)
        case .centerInside:
            centerInsideVideo(constraints: constraints, videoAspectRatio: videoAspectRatio)
        }
    }

    private func shouldCenterInsideVideo(constraints: ViewConstraints, videoAspectRatio: CGFloat) -> Bool {
        shouldShowMediaWhole(constraints: constraints, aspectRatio: videoAspectRatio)
    }

    @ViewBuilder
    @MainActor
    private func cropAlignedVideo(constraints: ViewConstraints, videoAspectRatio: CGFloat, alignment: Alignment = .center) -> some View {
        if shouldCenterInsideVideo(constraints: constraints, videoAspectRatio: videoAspectRatio) {
            centerInsideVideo(constraints: constraints, videoAspectRatio: videoAspectRatio)
        } else {
            self.aspectRatio(videoAspectRatio, contentMode: .fill)
                .constraints(constraints, alignment: alignment)
                // As above: a measured maximum is not a ceiling this view has to fit inside, and
                // this is the frame that crops on an axis the declared size left auto, so it is the
                // one the alignment has to reach.
                .frame(
                    maxWidth: constraints.limit(on: .horizontal),
                    maxHeight: constraints.limit(on: .vertical),
                    alignment: alignment
                )
                .clipped()
        }
    }

    @MainActor
    private func centerInsideVideo(constraints: ViewConstraints, videoAspectRatio: CGFloat ) -> some View {
        self.aspectRatio(videoAspectRatio, contentMode: .fit)
            .constraints(constraints)
    }
}

/// Whether media of [aspectRatio] can be shown whole at the length it was given.
///
/// Cropping is what you do to fit media into a box. An auto axis isn't a box — it takes whatever the
/// media turns out to be — so the only question is whether scaling to the axis that *was* given pushes
/// the other one past its maximum. If it doesn't, the media fits, and cropping would throw away pixels
/// for nothing.
///
/// A maximum that isn't there imposes no limit, so nothing can exceed it. Reading an absent one as a
/// reason to crop is what left an auto-height image scaled to fill and clipped to whatever height its
/// siblings happened to settle on, rather than to its own proportions.
private func shouldShowMediaWhole(constraints: ViewConstraints, aspectRatio: CGFloat) -> Bool {
    switch (constraints.width, constraints.height) {
    case (nil, let height?):
        guard let maxWidth = constraints.limit(on: .horizontal) else { return true }
        return height * aspectRatio <= maxWidth
    case (let width?, nil):
        guard let maxHeight = constraints.limit(on: .vertical) else { return true }
        return width / aspectRatio <= maxHeight
    // Both given is a box, and the media is cropped into it.
    case (_?, _?):
        return false
    // Neither declared, so the only box on offer is a maximum — and only a real one counts. Against
    // a ceiling the author can point at, `fit_crop` still means fill it and crop the overflow.
    // Against a measured one there is nothing to crop into: that number is the siblings' extent, and
    // obeying it rendered a `fit_crop` image beside a two-character label as a strip of itself the
    // label's width.
    case (nil, nil):
        return constraints.limit(on: .horizontal) == nil
            && constraints.limit(on: .vertical) == nil
    }
}

private extension ViewConstraints {
    /// The maximum on [axis], where there is one that actually limits anything.
    ///
    /// A maximum that isn't there imposes no limit, so nothing can exceed it. Neither does one an
    /// auto-sized ancestor arrived at by measuring: that is its own children's extent handed back as
    /// a ceiling, and the view now being measured against it is one of the children it was taken
    /// from. Media sized from such a maximum is capped by whatever its siblings happened to settle
    /// on — and it settles there, since the measurement that produced the cap then reproduces it.
    func limit(on axis: Axis) -> CGFloat? {
        let measured: Axis.Set = axis == .vertical ? .vertical : .horizontal
        guard !self.measuredAxes.contains(measured) else { return nil }
        return axis == .vertical ? self.maxHeight : self.maxWidth
    }
}
