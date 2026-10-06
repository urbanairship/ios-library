/* Copyright Airship and Contributors */

import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias ThomasPlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias ThomasPlatformColor = NSColor
#endif

extension View {
    /// Paints `backgrounds` behind this view's own content, without affecting how that content
    /// resolves its size -- the content lays itself out first, using whatever rules it already has,
    /// and only afterward is the layer stack composited into the resulting box. `.background` gives
    /// that ordering for free: it proposes this view's own resolved size to what's inside it.
    @ViewBuilder
    func thomasBackgrounds(_ backgrounds: [ThomasBackground]?) -> some View {
        if let backgrounds, !backgrounds.isEmpty {
            self.background {
                ThomasBackgroundStack(layers: backgrounds)
            }
        } else {
            self
        }
    }

    /// Like `thomasBackgrounds`, for `Pager`/`ScrollLayout`'s layers, which may also carry
    /// `parallax`, driven by an offset the host already re-renders for.
    ///
    /// - Parameters:
    ///   - backgrounds: The layers to paint, furthest back first.
    ///   - axis: The direction the host's content moves in; a layer's `factor` applies along it.
    ///   - contentOffset: the real content's own current offset on `axis`, in points, signed the
    ///     way the content already computes it. A layer's own offset is `factor * contentOffset`.
    ///   - maxTravel: the largest `|contentOffset|` can ever reach; sizes how much extra room a
    ///     moving layer needs so it never reveals a gap at the end of its travel.
    ///   - animation: the animation the real content settles with, applied to the layers only
    ///     when `animationValue` changes.
    ///   - animationValue: the value the real content keys its own settle animation to.
    /// - Returns: This view with the layers painted behind it.
    @ViewBuilder
    func thomasParallaxBackgrounds(
        _ backgrounds: [ThomasParallaxBackgroundLayer]?,
        axis: Axis,
        contentOffset: CGFloat,
        maxTravel: CGFloat,
        animation: Animation? = nil,
        animationValue: AnyHashable? = nil
    ) -> some View {
        if let backgrounds, !backgrounds.isEmpty {
            self.background {
                ThomasParallaxBackgroundStack(
                    layers: backgrounds,
                    axis: axis,
                    contentOffset: contentOffset,
                    maxTravel: maxTravel
                )
                // Scoped here, not around the host, so it can't animate the host's own changes.
                .animation(animation, value: animationValue)
                // Outside each layer's own offset, so the clip stays fixed to this view's frame.
                .clipped()
            }
        } else {
            self
        }
    }

    /// Like `thomasParallaxBackgrounds(_:axis:contentOffset:maxTravel:animation:animationValue:)`,
    /// for an offset that changes every scroll frame: only the layers observe `offsetTracker`, so
    /// the host doesn't re-render as it scrolls.
    ///
    /// - Parameters:
    ///   - backgrounds: The layers to paint, furthest back first.
    ///   - axis: The direction the host's content moves in; a layer's `factor` applies along it.
    ///   - offsetTracker: The content's live offset on `axis`, signed as for `contentOffset`.
    ///   - maxTravel: the largest `|offsetTracker.offset|` can ever reach.
    /// - Returns: This view with the layers painted behind it.
    @ViewBuilder
    func thomasParallaxBackgrounds(
        _ backgrounds: [ThomasParallaxBackgroundLayer]?,
        axis: Axis,
        offsetTracker: ThomasContentOffsetTracker,
        maxTravel: CGFloat
    ) -> some View {
        if let backgrounds, !backgrounds.isEmpty {
            self.background {
                ThomasTrackedParallaxBackgroundStack(
                    layers: backgrounds,
                    axis: axis,
                    offsetTracker: offsetTracker,
                    maxTravel: maxTravel
                )
                .clipped()
            }
        } else {
            self
        }
    }

    /// Writes how far this scroll view's content has moved from its leading edge into `offsetTracker`:
    /// 0 at rest, negative as the user scrolls forward.
    ///
    /// Read from the scroll view itself rather than its content, so nothing wraps the content.
    ///
    /// - Parameters:
    ///   - offsetTracker: The tracker to update.
    ///   - axis: The scroll axis.
    /// - Returns: This scroll view, reporting its offset.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
    func thomasTrackScrollOffset(
        _ offsetTracker: ThomasContentOffsetTracker,
        axis: Axis
    ) -> some View {
        self.onScrollGeometryChange(for: CGFloat.self) { geometry in
            axis == .vertical
                ? -(geometry.contentOffset.y + geometry.contentInsets.top)
                : -(geometry.contentOffset.x + geometry.contentInsets.leading)
        } action: { _, offset in
            offsetTracker.offset = offset
        }
    }

    /// Writes how far this scroll content has moved from its leading edge into `offsetTracker`:
    /// 0 at rest, negative as the user scrolls forward, in either layout direction.
    ///
    /// A right-to-left horizontal scroll rests at its physical end, so its raw origin starts at
    /// `-(content - viewport)`; measuring from the trailing side keeps it 0 at rest instead.
    ///
    /// - Parameters:
    ///   - offsetTracker: The tracker to update.
    ///   - axis: The scroll axis.
    ///   - coordinateSpaceName: The name of the scroll view's coordinate space.
    ///   - viewportLength: The scroll view's own length on `axis`.
    /// - Returns: This view, reporting its offset.
    func thomasTrackContentOffset(
        _ offsetTracker: ThomasContentOffsetTracker,
        axis: Axis,
        coordinateSpaceName: String,
        viewportLength: CGFloat
    ) -> some View {
        self.modifier(
            ThomasContentOffsetTracking(
                offsetTracker: offsetTracker,
                axis: axis,
                coordinateSpaceName: coordinateSpaceName,
                viewportLength: viewportLength
            )
        )
    }
}

private struct ThomasContentOffsetTracking: ViewModifier {
    let offsetTracker: ThomasContentOffsetTracker
    let axis: Axis
    let coordinateSpaceName: String
    let viewportLength: CGFloat
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        let measuresFromTrailingEdge = axis == .horizontal && layoutDirection == .rightToLeft
        content.onGeometryChange(for: CGFloat.self) { [coordinateSpaceName, viewportLength] proxy in
            let frame = proxy.frame(in: .named(coordinateSpaceName))
            if axis == .vertical { return frame.minY }
            return measuresFromTrailingEdge ? viewportLength - frame.maxX : frame.minX
        } action: { offset in
            offsetTracker.offset = offset
        }
    }
}

/// The live offset of a `Pager`/`ScrollLayout`'s content, which only its parallax layers observe.
///
/// Hosts hold it in `@State`, not `@StateObject`, so its changes don't re-render the host.
@MainActor
final class ThomasContentOffsetTracker: ObservableObject {
    @Published var offset: CGFloat = 0
}

private struct ThomasTrackedParallaxBackgroundStack: View {
    let layers: [ThomasParallaxBackgroundLayer]
    let axis: Axis
    @ObservedObject var offsetTracker: ThomasContentOffsetTracker
    let maxTravel: CGFloat

    var body: some View {
        ThomasParallaxBackgroundStack(
            layers: layers,
            axis: axis,
            contentOffset: offsetTracker.offset,
            maxTravel: maxTravel
        )
    }
}

/// The parallax layer array, furthest back at index 0, isolated for blending like
/// `ThomasBackgroundStack`.
private struct ThomasParallaxBackgroundStack: View {
    let layers: [ThomasParallaxBackgroundLayer]
    let axis: Axis
    let contentOffset: CGFloat
    let maxTravel: CGFloat

    /// The most extra length any layer needs; every layer reports it so they share one
    /// compositing buffer, sized to the travel actually used rather than the host's full range.
    private var sharedOversize: CGFloat {
        layers.map { abs(CGFloat($0.parallaxFactor)) * maxTravel }.max() ?? 0
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                    ThomasParallaxBackgroundLayerView(
                        layer: layer,
                        axis: axis,
                        frameSize: proxy.size,
                        contentOffset: contentOffset,
                        maxTravel: maxTravel,
                        sharedOversize: sharedOversize
                    )
                }
            }
            .compositingGroup()
        }
    }
}

/// One parallax-capable layer: the background, oversized along `axis` by its own travel, inside a
/// box padded to `sharedOversize`, offset by `factor` times the host's content offset.
private struct ThomasParallaxBackgroundLayerView: View {
    let layer: ThomasParallaxBackgroundLayer
    let axis: Axis
    let frameSize: CGSize
    let contentOffset: CGFloat
    let maxTravel: CGFloat
    let sharedOversize: CGFloat

    private var factor: CGFloat {
        CGFloat(layer.parallaxFactor)
    }

    /// Clamped to the travel `oversize` covers, so an overscroll bounce holds the layer still
    /// rather than pulling it past its edge.
    private var layerOffset: CGFloat {
        factor * min(0, max(-maxTravel, contentOffset))
    }

    /// The extra length this layer needs to cover its own travel (`factor * maxTravel`).
    private var oversize: CGFloat {
        abs(factor) * maxTravel
    }

    /// Where the layer rests before `layerOffset` applies: a positive `factor` moves it toward
    /// the start, so its slack trails; a negative one moves it toward the end, so it starts
    /// shifted back by `oversize` to put the slack on the leading edge.
    private var restingOffset: CGFloat {
        factor < 0 ? -oversize : 0
    }

    var body: some View {
        // Equatable, so a new offset each scroll frame doesn't re-run the layer's own body.
        ThomasBackgroundLayerView(background: layer.background)
            .equatable()
            .frame(
                width: frameSize.width + (axis == .horizontal ? oversize : 0),
                height: frameSize.height + (axis == .vertical ? oversize : 0),
                alignment: .topLeading
            )
            // Every layer reports the same size, so they agree on the shared compositing buffer;
            // reporting less here would get clipped before the offset below runs.
            .frame(
                width: frameSize.width + (axis == .horizontal ? sharedOversize : 0),
                height: frameSize.height + (axis == .vertical ? sharedOversize : 0),
                alignment: .topLeading
            )
            .offset(
                x: axis == .horizontal ? restingOffset + layerOffset : 0,
                y: axis == .vertical ? restingOffset + layerOffset : 0
            )
    }
}

/// The layer array, furthest back at index 0, matching `ContainerItem`'s own front-to-back
/// convention.
///
/// `.compositingGroup()` isolates the stack so a layer's `blend_mode` mixes only with the layers
/// behind it in this array -- without it, SwiftUI blends a layer against everything already drawn
/// in the wider scene, not just its own siblings here.
private struct ThomasBackgroundStack: View {
    let layers: [ThomasBackground]

    var body: some View {
        ZStack {
            ForEach(Array(layers.enumerated()), id: \.offset) { _, layer in
                ThomasBackgroundLayerView(background: layer)
            }
        }
        .compositingGroup()
    }
}

private struct ThomasBackgroundLayerView: View, Equatable {
    let background: ThomasBackground
    @Environment(\.thomasSelectorEnvironment) private var selectorEnvironment

    var body: some View {
        layerContent
            .opacity(background.opacity ?? 1)
            .blendMode(background.blendMode?.swiftUIBlendMode ?? .normal)
            .allowsHitTesting(background.acceptsTouches)
            // Decorative, with no `content_description`; a video with controls stays reachable.
            .accessibilityHidden(!background.acceptsTouches)
    }

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.background == rhs.background
    }

    @ViewBuilder
    private var layerContent: some View {
        switch background {
        case .color(let info):
            info.color.toColor(selectorEnvironment)
        case .gradient(let info):
            ThomasBackgroundGradientView(gradient: info.gradient)
        case .media(.image(let info)):
            ThomasBackgroundImageView(info: info)
        case .media(.video(let info)):
            ThomasBackgroundVideoView(info: info)
        }
    }
}

private struct ThomasBackgroundGradientView: View {
    let gradient: ThomasBackground.GradientBackground.Gradient
    @Environment(\.thomasSelectorEnvironment) private var selectorEnvironment

    /// Pre-blended in sRGB, rather than handed to `LinearGradient`/`RadialGradient` as the DSL's
    /// own stops directly: neither exposes a way to request sRGB-space interpolation, and their
    /// default doesn't match CSS/Android's. Inserting many correctly-blended intermediate stops
    /// confines the mismatch to a span too small to see.
    private var stops: [Gradient.Stop] {
        let resolved = gradient.stops.map { stop in
            let color = stop.color.toColor(selectorEnvironment)
            return (color: color, components: Self.sRGBComponents(of: color), position: stop.position)
        }
        guard resolved.count >= 2 else {
            return resolved.map { .init(color: $0.color, location: $0.position) }
        }

        // Sample count scales with the segment's own width, not a fixed count -- packing many
        // stops into a near-zero-width segment (a sharp edge) makes SwiftUI's gradient rendering
        // degenerate to a solid color across the whole gradient, not just that span.
        let maxSamplesPerSegment = 24
        var result: [Gradient.Stop] = []
        for i in 0..<(resolved.count - 1) {
            let start = resolved[i]
            let end = resolved[i + 1]
            let segmentWidth = end.position - start.position
            let samplesPerSegment = max(2, Int((Double(maxSamplesPerSegment) * segmentWidth).rounded()))
            for sample in 0..<samplesPerSegment {
                let t = Double(sample) / Double(samplesPerSegment)
                result.append(
                    .init(
                        color: Self.blendSRGB(start.components, end.components, t: t),
                        location: start.position + segmentWidth * t
                    )
                )
            }
        }
        result.append(.init(color: resolved.last!.color, location: resolved.last!.position))
        return result
    }

    /// Linear interpolation of two colors' sRGB-encoded components, premultiplied by alpha as
    /// CSS does, so a fade to `transparent` doesn't darken midway.
    ///
    /// - Parameters:
    ///   - startComponents: The sRGB components at `t == 0`.
    ///   - endComponents: The sRGB components at `t == 1`.
    ///   - t: The fraction of the way from start to end.
    /// - Returns: The blended color.
    private static func blendSRGB(_ startComponents: SRGBComponents, _ endComponents: SRGBComponents, t: Double) -> Color {
        let alpha = startComponents.alpha + (endComponents.alpha - startComponents.alpha) * t
        guard alpha > 0 else { return .clear }

        func channel(_ startValue: Double, _ endValue: Double) -> Double {
            let startPremultiplied = startValue * startComponents.alpha
            let endPremultiplied = endValue * endComponents.alpha
            return (startPremultiplied + (endPremultiplied - startPremultiplied) * t) / alpha
        }

        return Color(
            .sRGB,
            red: channel(startComponents.red, endComponents.red),
            green: channel(startComponents.green, endComponents.green),
            blue: channel(startComponents.blue, endComponents.blue),
            opacity: alpha
        )
    }

    private typealias SRGBComponents = (red: Double, green: Double, blue: Double, alpha: Double)

    private static func sRGBComponents(of color: Color) -> SRGBComponents {
        var platformColor = ThomasPlatformColor(color)
        #if canImport(AppKit) && !canImport(UIKit)
        // AppKit colors aren't guaranteed to already be in an RGB-component-bearing color space
        // (e.g. a catalog or pattern color); UIKit's are always RGB-queryable as-is.
        platformColor = platformColor.usingColorSpace(.deviceRGB) ?? platformColor
        #endif

        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        platformColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue), Double(alpha))
    }

    var body: some View {
        // CSS angles are physical; SwiftUI would otherwise mirror the `UnitPoint`s under RTL.
        gradientBody.environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder
    private var gradientBody: some View {
        switch gradient.style {
        case .linear:
            // A box's `UnitPoint` fraction for the gradient line's ends depends on its aspect
            // ratio at non-axis-aligned angles (CSS's corner-to-corner line length), so this
            // needs the actual size, not just a unit vector -- see `linearGradientPoints`.
            GeometryReader { proxy in
                let points = ThomasBackground.GradientBackground.Gradient.linearGradientPoints(
                    angle: gradient.angle,
                    size: proxy.size
                )
                LinearGradient(stops: stops, startPoint: points.start, endPoint: points.end)
            }
        case .radial:
            // Reaches the farthest corner from the centre -- CSS's own default radial extent.
            GeometryReader { proxy in
                RadialGradient(
                    stops: stops,
                    center: .center,
                    startRadius: 0,
                    endRadius: hypot(proxy.size.width, proxy.size.height) / 2
                )
            }
        }
    }
}

private struct ThomasBackgroundImageView: View {
    let info: ThomasBackground.MediaBackground.ImageMediaBackground
    @EnvironmentObject private var thomasEnvironment: ThomasEnvironment
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.thomasSelectorEnvironment) private var selectorEnvironment

    private var resolvedURL: String {
        let url = ThomasPropertyOverride.resolveRequired(
            state: thomasState,
            overrides: info.overrides?.url,
            defaultValue: info.url
        )
        let urlSelectors = ThomasPropertyOverride.resolveOptional(
            state: thomasState,
            overrides: info.overrides?.urlSelectors,
            defaultValue: info.urlSelectors
        )
        return urlSelectors?.resolve(selectorEnvironment) ?? url
    }

    var body: some View {
        GeometryReader { proxy in
            ThomasAsyncImage(
                url: resolvedURL,
                loadImage: thomasEnvironment.imageLoader.load
            ) { image, imageSize in
                image.fitMedia(
                    mediaFit: info.mediaFit,
                    cropPosition: info.position,
                    constraints: ViewConstraints(width: proxy.size.width, height: proxy.size.height),
                    imageSize: imageSize
                )
            } placeholder: {
                Color.clear
            }
        }
    }
}

/// Kept apart from `ThomasBackgroundImageView` so only video layers observe `PagerState`, whose
/// progress ticks many times a second during a story.
private struct ThomasBackgroundVideoView: View {
    let info: ThomasBackground.MediaBackground.VideoMediaBackground
    @EnvironmentObject private var pagerState: PagerState
    @EnvironmentObject private var thomasState: ThomasState
    @Environment(\.pageIdentifier) private var pageIdentifier
    @State private var videoID = UUID()
    @State private var registeredPageId: String?

    /// Returns the page this layer's video should hold up: the page it sits on, or, for a
    /// pager's own background (outside any of its pages), the page showing when it appears.
    ///
    /// `pageIdentifier` only counts when it names one of this `pagerState`'s pages -- a pager
    /// nested in another pager's page inherits the outer page's id. Outside any pager this is
    /// `""`, which matches no page, the same as never registering.
    private var resolvedPageId: String {
        if let pageIdentifier, pagerState.pageItems.contains(where: { $0.identifier == pageIdentifier }) {
            return pageIdentifier
        }
        return pagerState.currentPageId ?? ""
    }

    /// Registers the video under `resolvedPageId` and remembers it, so `markMediaReady` clears
    /// the same entry even if the page turns while the video loads.
    private func registerMedia() {
        let pageId = registeredPageId ?? resolvedPageId
        registeredPageId = pageId
        pagerState.registerMedia(pageId: pageId, id: videoID)
    }

    private func markMediaReady() {
        pagerState.setMediaReady(pageId: registeredPageId ?? resolvedPageId, id: videoID, isReady: true)
    }

    var body: some View {
        switch info.mediaType {
        case .image:
            Color.clear
        case .video:
#if os(watchOS)
            Color.clear
#elseif os(macOS)
            // `VideoMediaNativeView` excludes macOS (AVPlayer/UIKit-backed), so this routes
            // through the WebKit-backed `VideoMediaWebView` instead, which already handles a
            // plain `<video>` tag.
            GeometryReader { proxy in
                let playerInfo = info.playerInfo.resolvingURLOverrides(state: thomasState)
                VideoMediaWebView(
                    info: playerInfo,
                    videoIdentifier: videoID.uuidString,
                    onMediaReady: markMediaReady
                )
                .id(playerInfo.properties.url)
                .constraints(ViewConstraints(width: proxy.size.width, height: proxy.size.height))
                .onAppear(perform: registerMedia)
            }
#else
            // The same AVPlayer-backed view the in-flow `media_type: video` case renders
            // (`Media.swift`), fed the `ThomasViewInfo.Media` decoded alongside this layer. It
            // reads `isVisible`/`VideoState` from this view's own position in the tree.
            GeometryReader { proxy in
                let playerInfo = info.playerInfo.resolvingURLOverrides(state: thomasState)
                VideoMediaNativeView(
                    info: playerInfo,
                    videoIdentifier: videoID.uuidString,
                    constraints: ViewConstraints(width: proxy.size.width, height: proxy.size.height),
                    videoAspectRatio: CGFloat(info.video?.aspectRatio ?? (16.0 / 9.0)),
                    showsErrorView: false,
                    onMediaReady: markMediaReady
                )
                .id(playerInfo.properties.url)
                .onAppear(perform: registerMedia)
            }
#endif
        case .youtube, .vimeo:
#if !os(tvOS) && !os(watchOS)
            // The same `WKWebView`-backed player the in-flow `youtube`/`vimeo` case renders
            // (`Media.swift`), fed the same `playerInfo` the `.video` case above uses.
            GeometryReader { proxy in
                let playerInfo = info.playerInfo.resolvingURLOverrides(state: thomasState)
                VideoMediaWebView(
                    info: playerInfo,
                    videoIdentifier: videoID.uuidString,
                    onMediaReady: markMediaReady
                )
                .id(playerInfo.properties.url)
                .constraints(ViewConstraints(width: proxy.size.width, height: proxy.size.height))
                .onAppear(perform: registerMedia)
            }
#else
            Color.clear
#endif
        }
    }
}
