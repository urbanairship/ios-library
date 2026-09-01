/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// A scroll hands its own frame down as the length percentages inside it resolve against, since the
/// axis it scrolls is measured unbounded and offers them nothing else.
///
/// A scene authored before that was offered was laid out around those percentages falling back to
/// their own content — an empty `100%` at the end of a scroll drew nothing, where borrowing the
/// viewport gives it a screenful of blank. So version 1 gets the axis it scrolls cleared, which is
/// what the renderer did for every scene beforehand, and the other axis exactly as it arrived.
@Suite("Scroll viewport by layout version")
struct ScrollViewportVersionTest {

    private let measured = CGSize(width: 400, height: 800)

    @Test("the viewport reaches a scene that asks for it")
    func viewportAtVersionTwo() {
        let content = ViewConstraints(width: 400, height: nil)
        let filled = content.fillingScrollViewport(measured, isVertical: true, layoutVersion: 2)

        #expect(filled.height == 800)
        #expect(filled.measuredAxes.contains(.vertical))
    }

    @Test("a version 1 scene is handed no viewport")
    func viewportAtVersionOne() {
        let content = ViewConstraints(width: 400, height: nil)
        let filled = content.fillingScrollViewport(measured, isVertical: true, layoutVersion: 1)

        #expect(filled.height == nil)
        #expect(!filled.measuredAxes.contains(.vertical))
    }

    /// The case that declining to fill the axis does not cover: a scroll sized in points by its
    /// parent carries a length already, and passing it on resolves the percentages inside against
    /// it — where they used to fall back to their own content.
    @Test("a length the scroll inherited is cleared for a version 1 scene")
    func inheritedLengthIsCleared() {
        let content = ViewConstraints(width: 400, height: 300)
        let filled = content.fillingScrollViewport(measured, isVertical: true, layoutVersion: 1)

        #expect(filled.height == nil)
        #expect(filled.width == 400)
    }

    @Test("and is kept for a scene that asks for the viewport")
    func inheritedLengthSurvivesAtVersionTwo() {
        let content = ViewConstraints(width: 400, height: 300)
        let filled = content.fillingScrollViewport(measured, isVertical: true, layoutVersion: 2)

        #expect(filled.height == 300)
        #expect(filled.width == 400)
    }

    @Test("the other axis arrives as it left, at either version")
    func crossAxisIsUntouched() {
        let stated = ViewConstraints(width: 320, height: nil)
        for version in [1, 2] {
            let filled = stated.fillingScrollViewport(
                measured,
                isVertical: true,
                layoutVersion: version
            )
            #expect(filled.width == 320)
        }
    }

    @Test("a horizontal scroll clears its width instead")
    func horizontalClearsWidth() {
        let content = ViewConstraints(width: 300, height: 400)
        let filled = content.fillingScrollViewport(measured, isVertical: false, layoutVersion: 1)

        #expect(filled.width == nil)
        #expect(filled.height == 400)
    }
}
