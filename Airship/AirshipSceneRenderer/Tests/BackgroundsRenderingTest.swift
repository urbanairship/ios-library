/* Copyright Airship and Contributors */

#if !os(macOS) && !os(watchOS)

import CoreGraphics
import SwiftUI
import Testing
import UIKit

@_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Covers `thomasBackgrounds`'s one load-bearing guarantee: a layer paints into whatever box the
/// host already resolved, and never grows or shrinks that box itself.
///
/// Measured through a real hosted view rather than a pure function, since the guarantee is a
/// property of `.background`'s own layout behavior, not of anything `thomasBackgrounds` computes.
@MainActor
struct BackgroundsRenderingTest {

    private final class StubThomasDelegate: ThomasDelegate {
        func onVisibilityChanged(isVisible: Bool, isForegrounded: Bool) {}
        func onReportingEvent(_ event: ThomasReportingEvent) {}
        func onDismissed(cancel: Bool) {}
        func onStateChanged(_ state: AirshipJSON) {}
    }

    // Hosted media layers read ThomasEnvironment, ThomasState, VideoState and PagerState as
    // environment objects, and crash if any is missing.
    private let thomasEnvironment = ThomasEnvironment(delegate: StubThomasDelegate(), extensions: TestThomasExtensions())
    private let thomasState = ThomasState(onStateChange: { _ in })
    private let videoState = VideoState(identifier: "test")
    private let pagerState = PagerState(identifier: "test", branching: nil)

    private func measuredSize<V: View>(of content: V) async throws -> CGSize? {
        var reported: CGSize?
        let probed = content
            .environmentObject(thomasEnvironment)
            .environmentObject(thomasState)
            .environmentObject(videoState)
            .environmentObject(pagerState)
            .background(
                ThomasSceneSizeReader { size in reported = size }
            )

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let host = UIHostingController(rootView: probed)
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(60))

        return reported
    }

    /// A host that hugs its own content, the way an auto-sized `Container`/`LinearLayout` does --
    /// standing in for one without pulling in `ThomasEnvironment`/`ThomasState`, which the real
    /// hosts need but this guarantee doesn't depend on.
    private func autoSizedHost() -> some View {
        Color.blue.frame(width: 60, height: 40)
    }

    private func backgrounds(_ json: String) throws -> [ThomasBackground] {
        try JSONDecoder().decode([ThomasBackground].self, from: json.data(using: .utf8)!)
    }

    private func parallaxBackgrounds(_ json: String) throws -> [ThomasParallaxBackgroundLayer] {
        try JSONDecoder().decode([ThomasParallaxBackgroundLayer].self, from: json.data(using: .utf8)!)
    }

    @Test
    func colorLayerDoesNotChangeAutoSizedHostSize() async throws {
        let layers = try backgrounds("""
            [{ "type": "color", "color": { "default": { "hex": "#FF0000", "alpha": 1 } } }]
            """)

        let plain = try await measuredSize(of: autoSizedHost())
        let backed = try await measuredSize(of: autoSizedHost().thomasBackgrounds(layers))

        #expect(plain != nil)
        #expect(plain == backed)
    }

    @Test
    func gradientLayerDoesNotChangeAutoSizedHostSize() async throws {
        let layers = try backgrounds("""
            [{
                "type": "gradient",
                "gradient": {
                    "style": "radial",
                    "stops": [
                        { "color": { "default": { "hex": "#000000", "alpha": 0 } }, "position": 0 },
                        { "color": { "default": { "hex": "#000000", "alpha": 1 } }, "position": 1 }
                    ]
                }
            }]
            """)

        let plain = try await measuredSize(of: autoSizedHost())
        let backed = try await measuredSize(of: autoSizedHost().thomasBackgrounds(layers))

        #expect(plain != nil)
        #expect(plain == backed)
    }

    /// A background image, routed through `ThomasBackgroundMediaView`'s `GeometryReader` +
    /// `fitMedia` -- the same fit math `Media` uses, wrapped so it never demands more room than
    /// the host already resolved.
    @Test
    func mediaLayerDoesNotChangeAutoSizedHostSize() async throws {
        let layers = try backgrounds("""
            [{
                "type": "media",
                "media_type": "image",
                "url": "https://example.com/does-not-load.jpg",
                "media_fit": "fit_crop"
            }]
            """)

        let plain = try await measuredSize(of: autoSizedHost())
        let backed = try await measuredSize(of: autoSizedHost().thomasBackgrounds(layers))

        #expect(plain != nil)
        #expect(plain == backed)
    }

    /// A video layer routes through the exact same `VideoMediaNativeView` the in-flow
    /// `media_type: video` case renders through (built from a synthetic `ThomasViewInfo.Media`
    /// round-tripped through the DSL's own wire format) -- confirms that path mounts at all
    /// (a missing `VideoState`/`isVisible` would crash outright, not render wrong) and still
    /// leaves the host's own size alone.
    @Test
    func videoLayerDoesNotChangeAutoSizedHostSize() async throws {
        let layers = try backgrounds("""
            [{
                "type": "media",
                "media_type": "video",
                "url": "https://example.com/does-not-load.mp4",
                "media_fit": "fit_crop",
                "video": { "autoplay": false, "muted": true, "loop": false }
            }]
            """)

        let plain = try await measuredSize(of: autoSizedHost())
        let backed = try await measuredSize(of: autoSizedHost().thomasBackgrounds(layers))

        #expect(plain != nil)
        #expect(plain == backed)
    }

    /// Several layers together, each with its own `blend_mode`/`opacity` -- covers that stacking
    /// layers and compositing them doesn't itself grow the box, on top of a single layer.
    @Test
    func multipleLayeredBackgroundsDoNotChangeAutoSizedHostSize() async throws {
        let layers = try backgrounds("""
            [
                { "type": "color", "color": { "default": { "hex": "#0B1B33", "alpha": 1 } } },
                {
                    "type": "gradient",
                    "blend_mode": "multiply",
                    "gradient": {
                        "style": "linear",
                        "angle": 180,
                        "stops": [
                            { "color": { "default": { "hex": "#000000", "alpha": 0 } }, "position": 0 },
                            { "color": { "default": { "hex": "#000000", "alpha": 0.6 } }, "position": 1 }
                        ]
                    }
                }
            ]
            """)

        let plain = try await measuredSize(of: autoSizedHost())
        let backed = try await measuredSize(of: autoSizedHost().thomasBackgrounds(layers))

        #expect(plain != nil)
        #expect(plain == backed)
    }

    /// `Pager`/`ScrollLayout`'s layer shape, which also carries `parallax` -- oversized and
    /// mid-travel (non-zero `contentOffset`/`maxTravel`), not just at rest, since that's exactly
    /// where an oversized inner layer leaking into the host's own size would show up.
    @Test
    func parallaxBackgroundLayerDoesNotChangeAutoSizedHostSize() async throws {
        let layers = try parallaxBackgrounds("""
            [{
                "type": "color",
                "color": { "default": { "hex": "#FF0000", "alpha": 1 } },
                "parallax": { "factor": 0.4 }
            }]
            """)

        let plain = try await measuredSize(of: autoSizedHost())
        let backed = try await measuredSize(
            of: autoSizedHost().thomasParallaxBackgrounds(
                layers,
                axis: .vertical,
                contentOffset: -20,
                maxTravel: 50
            )
        )

        #expect(plain != nil)
        #expect(plain == backed)
    }
}

#endif
