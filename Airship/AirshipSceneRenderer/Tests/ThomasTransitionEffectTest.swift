/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite(.timeLimit(.minutes(1)))
struct ThomasTransitionEffectTest {

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    // MARK: - Modal

    @Test
    func modalFade() throws {
        let json = """
        { "in": { "type": "fade", "duration_milliseconds": 200 },
          "out": { "type": "fade", "duration_milliseconds": 300 } }
        """

        let transition = try decoder.decode(
            ThomasPresentationInfo.Modal.Transition.self,
            from: json.data(using: .utf8)!
        )

        guard case .fade(let enter) = transition.enter, case .fade(let exit) = transition.exit else {
            Issue.record("Expected fade in and out")
            return
        }
        #expect(enter.durationMilliseconds == 200)
        #expect(exit.durationMilliseconds == 300)
    }

    @Test
    func modalSlideWithDifferentEdgesInAndOut() throws {
        let json = """
        { "in": { "type": "slide", "edge": { "horizontal": "center", "vertical": "top" } },
          "out": { "type": "slide", "edge": { "horizontal": "center", "vertical": "bottom" } } }
        """

        let transition = try decoder.decode(
            ThomasPresentationInfo.Modal.Transition.self,
            from: json.data(using: .utf8)!
        )

        guard case .slide(let enter) = transition.enter, case .slide(let exit) = transition.exit else {
            Issue.record("Expected slide in and out")
            return
        }
        #expect(enter.edge.vertical == .top)
        #expect(exit.edge.vertical == .bottom)
    }

    @Test
    func modalDifferentEffectsInAndOut() throws {
        let json = """
        { "in": { "type": "explode", "corner": { "horizontal": "start", "vertical": "top" } },
          "out": { "type": "fade" } }
        """

        let transition = try decoder.decode(
            ThomasPresentationInfo.Modal.Transition.self,
            from: json.data(using: .utf8)!
        )

        guard case .explode(let enter) = transition.enter else {
            Issue.record("Expected explode in")
            return
        }
        guard case .fade = transition.exit else {
            Issue.record("Expected fade out")
            return
        }
        #expect(enter.corner.horizontal == .start)
        #expect(enter.corner.vertical == .top)
        #expect(!transition.isPlainFade)
    }

    @Test
    func modalIsPlainFadeOnlyWhenBothDirectionsFade() throws {
        let bothFade = try decoder.decode(
            ThomasPresentationInfo.Modal.Transition.self,
            from: """
            { "in": { "type": "fade" }, "out": { "type": "fade" } }
            """.data(using: .utf8)!
        )
        #expect(bothFade.isPlainFade)

        let mixed = try decoder.decode(
            ThomasPresentationInfo.Modal.Transition.self,
            from: """
            { "in": { "type": "fade" }, "out": { "type": "slide", "edge": { "horizontal": "center", "vertical": "top" } } }
            """.data(using: .utf8)!
        )
        #expect(!mixed.isPlainFade)
    }

    @Test
    func modalRoundTrip() throws {
        let transition = ThomasPresentationInfo.Modal.Transition(
            enter: .explode(
                ThomasPresentationInfo.Modal.ExplodeEffect(
                    durationMilliseconds: 600,
                    corner: ThomasCornerPosition(horizontal: .start, vertical: .bottom)
                )
            ),
            exit: .fade(ThomasPresentationInfo.Modal.FadeEffect(durationMilliseconds: 400))
        )

        let restored = try decoder.decode(
            ThomasPresentationInfo.Modal.Transition.self,
            from: encoder.encode(transition)
        )

        #expect(restored == transition)
    }

    // MARK: - Banner

    @Test
    func bannerFade() throws {
        let json = """
        { "in": { "type": "fade", "duration_milliseconds": 300 },
          "out": { "type": "fade", "duration_milliseconds": 300 } }
        """

        let transition = try decoder.decode(
            ThomasPresentationInfo.Banner.Transition.self,
            from: json.data(using: .utf8)!
        )

        guard case .fade(let enter) = transition.enter, case .fade(let exit) = transition.exit else {
            Issue.record("Expected fade in and out")
            return
        }
        #expect(enter.durationMilliseconds == 300)
        #expect(exit.durationMilliseconds == 300)
    }

    @Test
    func bannerSlideHasNoEdgeOfItsOwn() throws {
        let json = """
        { "in": { "type": "slide" }, "out": { "type": "slide" } }
        """

        let transition = try decoder.decode(
            ThomasPresentationInfo.Banner.Transition.self,
            from: json.data(using: .utf8)!
        )

        guard case .slide = transition.enter, case .slide = transition.exit else {
            Issue.record("Expected slide in and out")
            return
        }
    }

    @Test
    func bannerRoundTrip() throws {
        let transition = ThomasPresentationInfo.Banner.Transition(
            enter: .fade(ThomasPresentationInfo.Banner.FadeEffect(durationMilliseconds: 500)),
            exit: .slide(ThomasPresentationInfo.Banner.SlideEffect(durationMilliseconds: 250))
        )

        let restored = try decoder.decode(
            ThomasPresentationInfo.Banner.Transition.self,
            from: encoder.encode(transition)
        )

        #expect(restored == transition)
    }
}
