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

    /// Whether there is nothing here to crop into: no length on either axis, and no ceiling that is
    /// a box rather than a measurement.
    ///
    /// One length is box enough, because the axis left `auto` is capped at the aspect — filling that
    /// box throws away nothing the aspect could have covered, and a stack that rations the axis down
    /// crops, which is what a cropping fit asks for. Comparing the aspect against the *maximum*
    /// instead answers for a box the item may never get: a stack settles the length afterwards, and
    /// an image that was told it fits letterboxes inside whatever it is finally given.
    private func hasNoBoxToCropInto(constraints: ViewConstraints) -> Bool {
        constraints.resolvedLength(on: .horizontal) == nil
            && constraints.resolvedLength(on: .vertical) == nil
            && constraints.limit(on: .horizontal) == nil
            && constraints.limit(on: .vertical) == nil
    }

    @ViewBuilder
    @MainActor
    private func cropAligned(constraints: ViewConstraints, imageSize: CGSize, alignment: Alignment = .center) -> some View {
        if hasNoBoxToCropInto(constraints: constraints) {
            centerInside(constraints: constraints)
        } else {
            CroppedImage(
                image: self,
                constraints: constraints,
                imageSize: imageSize,
                alignment: alignment
            )
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

/// An image scaled to fill the space it was given and cropped to it.
///
/// What the layout sees is the sizing element; the image only draws. Filling makes an image answer
/// with the length its aspect implies whatever it is proposed, which reads as rigid: a stack pays
/// the least flexible item first, so a filled image takes the whole axis and a percentage beside it
/// is left with its own content. An `auto` axis is a preference rather than a claim, and stating it
/// as an ideal lets equal claimants divide the axis the way they do everywhere else.
///
/// The fitted path needs none of this — `scaledToFit` answers within what it is offered — which is
/// why `center_inside` divided an axis while the cropping fits did not.
private struct CroppedImage: View {
    let image: Image
    let constraints: ViewConstraints
    let imageSize: CGSize
    let alignment: Alignment

    var body: some View {
        let horizontal = autoBound(on: .horizontal)
        let vertical = autoBound(on: .vertical)

        Color.clear
            .frame(
                idealWidth: horizontal,
                maxWidth: horizontal,
                idealHeight: vertical,
                maxHeight: vertical
            )
            .constraints(constraints, alignment: alignment)
            // Carries the alignment because the image overflows the box it fills, and this is what
            // decides which side is cut: centered by default, and where `position` asked for an
            // edge, that edge is kept.
            .overlay(alignment: alignment) {
                image.resizable().scaledToFill()
            }
            // The same bound again on the way out, because a frame fills what it is proposed up to
            // its maximum: left at `limit(on:)` this one grew past the aspect the sizing element
            // had just settled, and the fill was drawn in the middle of the slack.
            .frame(
                maxWidth: horizontal ?? constraints.limit(on: .horizontal),
                maxHeight: vertical ?? constraints.limit(on: .vertical),
                alignment: alignment
            )
            .clipped()
    }

    /// The most an axis without a length of its own may take, which is also what it takes when
    /// nothing squeezes it. Nil on an axis the author gave a length, which `constraints(_:)` sets.
    ///
    /// Three readings, in order:
    ///
    /// - The other axis has a length the author wrote. Then this one is the aspect applied to it.
    ///   A ceiling caps that, so an image longer than the room is cropped into the room — unless
    ///   the ceiling is this view's own extent handed back, which caps nothing: the parent is
    ///   measuring this axis *from* us, and answering with its last measurement is how an
    ///   auto-sized box settles as a strip of itself.
    /// - Neither axis was declared, and there is a ceiling here. Then the ceiling is a box the
    ///   author can point at, and a cropping fit means fill it — unless the ceiling is this view's
    ///   own extent pinned rather than measured, in which case the aspect off the other axis's
    ///   ceiling gets a vote too, and the larger of the two wins. A pinned ceiling alone only ever
    ///   reports what this view already was, so a sibling settling wider than it, the way the
    ///   widest item in the stack does, would otherwise never pull this axis up to match.
    /// - Neither, and no ceiling here either. Then the aspect off the other axis's ceiling, and
    ///   failing that the image's own length.
    ///
    /// Android splits the same cases in `MediaView.onMeasure`, reading the item's declared size
    /// rather than the spec for the same reason: a stack that has settled its own length remeasures
    /// its children against it, and an `auto` child is one of the children that length came from.
    ///
    /// Stated with no floor under it, so a stack with less to give rations this axis down and the
    /// fill crops.
    private func autoBound(on axis: Axis) -> CGFloat? {
        guard imageSize.width > 0,
              imageSize.height > 0,
              declaredLength(on: axis) == nil
        else {
            return nil
        }

        let other: Axis = axis == .vertical ? .horizontal : .vertical
        let axisSet: Axis.Set = axis == .vertical ? .vertical : .horizontal
        let floor = (axis == .vertical ? constraints.frameMinHeight : constraints.frameMinWidth) ?? 0

        if let basis = declaredLength(on: other)?.safeValue {
            guard let length = derived(from: basis, on: axis) else { return nil }
            let ceiling = constraints.pinnedAxes.contains(axisSet)
                ? nil
                : constraints.limit(on: axis)?.safeValue
            return max(ceiling.map { min(length, $0) } ?? length, floor)
        }

        if let ceiling = constraints.limit(on: axis)?.safeValue {
            // A pinned ceiling on this same axis is our own extent handed back rather than a box the
            // author pointed at, so on its own it only ever reports what we already were — a sibling
            // that grows past it, the way the widest item in the stack does, would otherwise never
            // pull us up past a first measurement taken before either of us had settled. Deriving from
            // the other axis is the same claim a real box would make, so the larger of the two wins:
            // whichever candidate is closer to what the stack actually needs next.
            guard constraints.pinnedAxes.contains(axisSet),
                  let basis = constraints.limit(on: other)?.safeValue,
                  let derivedLength = derived(from: basis, on: axis)
            else {
                return max(ceiling, floor)
            }
            return max(ceiling, derivedLength, floor)
        }

        guard let basis = constraints.limit(on: other)?.safeValue,
              let length = derived(from: basis, on: axis)
        else {
            return max(axis == .horizontal ? imageSize.width : imageSize.height, floor)
        }

        return max(length, floor)
    }

    /// The length the author wrote on [axis], as opposed to one a parent arrived at by measuring
    /// this view and handed back as a share of itself.
    private func declaredLength(on axis: Axis) -> CGFloat? {
        axis == .vertical ? constraints.height : constraints.width
    }

    /// [axis]'s length at the image's own aspect, given the other axis's [basis].
    private func derived(from basis: CGFloat, on axis: Axis) -> CGFloat? {
        let aspectRatio = imageSize.width / imageSize.height
        return switch axis {
        case .horizontal: (basis * aspectRatio).safeValue
        case .vertical: (basis / aspectRatio).safeValue
        }
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
/// The video path only. An image asks the narrower `hasNoBoxToCropInto`, because `CroppedImage` caps
/// its auto axis at the aspect and so has a box to crop into as soon as one length exists. Here the
/// aspect sets the frame outright, and the comparison below is against a maximum rather than the
/// length a stack finally rations out.
///
/// A maximum that isn't there imposes no limit, so nothing can exceed it, and one an auto-sized
/// ancestor arrived at by measuring is its own children's extent rather than a box.
func shouldShowMediaWhole(constraints: ViewConstraints, aspectRatio: CGFloat) -> Bool {
    switch (constraints.resolvedLength(on: .horizontal), constraints.resolvedLength(on: .vertical)) {
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

extension ViewConstraints {
    /// The maximum on [axis], where there is one that actually limits anything.
    ///
    /// A maximum that isn't there imposes no limit, so nothing can exceed it. Neither does one an
    /// auto-sized ancestor arrived at by measuring: that is its own children's extent handed back as
    /// a ceiling, and the view now being measured against it is one of the children it was taken
    /// from. Media sized from such a maximum is capped by whatever its siblings happened to settle
    /// on — and it settles there, since the measurement that produced the cap then reproduces it.
    ///
    /// Except where `pinnedAxes` marks it: a child that asked for the whole of its container has
    /// its share floored rather than kept as a length, so the container stays free to grow past its
    /// own first measurement — but that floor and this ceiling name the same number, which is what
    /// a share of the whole *is*, not a coincidence of measuring. That pair is as real a length as
    /// one declared outright.
    func limit(on axis: Axis) -> CGFloat? {
        let axisSet: Axis.Set = axis == .vertical ? .vertical : .horizontal
        let ceiling = axis == .vertical ? self.maxHeight : self.maxWidth
        guard self.measuredAxes.contains(axisSet) else { return ceiling }
        return self.pinnedAxes.contains(axisSet) ? ceiling : nil
    }

    /// [axis]'s length, including one pinned by an equal floor rather than stated outright.
    ///
    /// A child that asked for the whole of a measured container ends up pinned rather than in
    /// `width`/`height` themselves — see `limit(on:)` — so deciding whether a box exists on this
    /// axis at all has to look at both.
    ///
    /// Only a pinned axis can carry a length this way. An un-measured maximum is the room the view
    /// was given, not a length it has, and reading it as one turned every declared-plus-auto media
    /// into a box on the auto axis too — crop always won, and the fits-so-show-it-whole comparison
    /// below it never ran.
    func resolvedLength(on axis: Axis) -> CGFloat? {
        let declared = axis == .vertical ? self.height : self.width
        if let declared { return declared }
        let axisSet: Axis.Set = axis == .vertical ? .vertical : .horizontal
        guard self.pinnedAxes.contains(axisSet) else { return nil }
        return limit(on: axis)
    }
}
