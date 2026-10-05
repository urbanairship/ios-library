/* Copyright Airship and Contributors */

import Foundation
import SwiftUI
import Testing

@testable @_spi(AirshipInternal) import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

/// Suspends every sleep until the test releases it.
@MainActor
private final class GatedTaskSleeper: AirshipTaskSleeper, @unchecked Sendable {
    private var waiting: [CheckedContinuation<Void, Never>] = []

    nonisolated func sleep(timeInterval: TimeInterval) async throws {
        await wait()
    }

    private func wait() async {
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Resumes the sleeps started so far and lets the tasks behind them run.
    func release() async {
        while waiting.isEmpty { await Task.yield() }
        let resumed = waiting
        waiting.removeAll()
        resumed.forEach { $0.resume() }
        for _ in 0..<10 { await Task.yield() }
    }
}

@MainActor
@Suite("ThomasEnvironmentState", .timeLimit(.minutes(1)))
struct ThomasEnvironmentStateTest {

    private func traits(
        darkMode: Bool = false,
        textScale: Double = 1,
        layoutDirection: LayoutDirection = .leftToRight
    ) -> ThomasEnvironmentState.Traits {
        ThomasEnvironmentState.Traits(
            darkMode: darkMode,
            textScale: textScale,
            windowSize: .medium,
            layoutDirection: layoutDirection,
            locale: Locale(identifier: "fr-CA")
        )
    }

    private func values(
        darkMode: Bool = false,
        textScale: Double = 1,
        window: CGSize? = CGSize(width: 390, height: 844)
    ) -> ThomasEnvironmentState.Values {
        ThomasEnvironmentState.Values(
            traits: traits(darkMode: darkMode, textScale: textScale),
            geometry: .init(window: window)
        )
    }

    private func environment(_ state: ThomasState) -> AirshipJSON? {
        state.state.object?[ThomasEnvironmentState.stateKey]
    }

    private func predicate(_ json: String) throws -> JSONPredicate {
        try JSONDecoder().decode(JSONPredicate.self, from: Data(json.utf8))
    }

    @Test
    func jsonCarriesEveryField() {
        let expected: AirshipJSON = [
            "platform": "ios",
            "dark_mode": true,
            "text_scale": 1.5,
            "layout_direction": "ltr",
            "locale": ["identifier": "fr-CA", "language": "fr", "region": "CA"],
            "window": [
                "orientation": "portrait",
                "size": "medium"
            ],
            "conditions": [:]
        ]
        #expect(values(darkMode: true, textScale: 1.5).json == expected)
    }

    /// The scene's `environment_state.conditions`: compact up to 599 wide, else expanded.
    private func sizeConditions() throws -> [String: [ThomasEnvironmentConditionSelector]] {
        try JSONDecoder().decode([String: [ThomasEnvironmentConditionSelector]].self, from: Data(#"""
        {"size": [{"window_width": {"at_most": 599}, "value": "compact"}, {"value": "expanded"}]}
        """#.utf8))
    }

    @Test
    func orientationIsLandscapeOnlyWhenWiderThanTall() {
        #expect(values(window: CGSize(width: 844, height: 390)).json.object?["window"]?.object?["orientation"] == "landscape")
        #expect(values(window: CGSize(width: 500, height: 500)).json.object?["window"]?.object?["orientation"] == "portrait")
    }

    @Test
    func unmeasuredWindowKeepsOnlyItsSizeClass() {
        #expect(values(window: nil).json.object?["window"] == ["size": "medium"])
    }

    @Test
    func rightToLeftLayoutDirection() {
        let rtl = ThomasEnvironmentState.Values(traits: traits(layoutDirection: .rightToLeft))
        #expect(rtl.json.object?["layout_direction"] == "rtl")
    }

    @Test
    func localeWithoutARegionLeavesRegionOut() {
        var french = values()
        french.traits.locale = Locale(identifier: "fr")
        #expect(french.json.object?["locale"] == ["identifier": "fr", "language": "fr"])
    }

    @Test
    func languagePredicateMatchesEveryRegion() throws {
        let french = try predicate(#"{"scope": ["$environment", "locale", "language"], "value": {"equals": "fr"}}"#)
        var scene = values()
        #expect(french.evaluate(json: [ThomasEnvironmentState.stateKey: scene.json]))

        scene.traits.locale = Locale(identifier: "fr-FR")
        #expect(french.evaluate(json: [ThomasEnvironmentState.stateKey: scene.json]))
    }

    @Test("$environment holds no window, safe window or frame sizes")
    func jsonHoldsNoSizes() {
        var measured = values()
        measured.geometry.safeWindow = CGSize(width: 390, height: 763)
        measured.geometry.frame = .init(width: 350, height: 500)

        #expect(measured.json.object?["window"] == ["orientation": "portrait", "size": "medium"])
        #expect(measured.json.object?["safe_window"] == nil)
        #expect(measured.json.object?["frame"] == nil)
    }

    @Test("environment conditions are chosen from the window and follow it across a breakpoint")
    func conditionsFollowTheWindow() throws {
        let environmentState = ThomasEnvironmentState(values: values(), conditions: try sizeConditions())
        #expect(environmentState.values.json.object?["conditions"] == ["size": "compact"])

        environmentState.update(window: CGSize(width: 1024, height: 768), safeWindow: CGSize(width: 1024, height: 768))
        #expect(environmentState.values.json.object?["conditions"] == ["size": "expanded"])
    }

    /// An embedded scene isn't seeded with the window, so its first renders come before any measure.
    @Test("an unseeded scene publishes no conditions until the window is measured")
    func conditionsWaitForTheWindow() throws {
        let environmentState = ThomasEnvironmentState(values: values(window: nil), conditions: try sizeConditions())
        #expect(environmentState.values.json.object?["conditions"] == [:])

        environmentState.update(window: CGSize(width: 390, height: 844), safeWindow: CGSize(width: 390, height: 844))
        #expect(environmentState.values.json.object?["conditions"] == ["size": "compact"])
    }

    /// An auto-height embedded view: the host decides the width, the scene's content the height.
    @Test("a frame length the host leaves open matches no range")
    func frameLeftOpenMatchesNoRange() throws {
        let conditions = try JSONDecoder().decode([String: [ThomasEnvironmentConditionSelector]].self, from: Data(#"""
        {"tall": [{"frame_height": {"at_least": 0}, "value": true}],
         "framed": [{"frame_width": {"at_least": 0}, "value": true}]}
        """#.utf8))
        var embedded = values()
        embedded.geometry.frame = .init(width: 390, height: nil)
        #expect(embedded.choosing(conditions).conditions == ["framed": true])
    }

    @Test
    func stateExposesEnvironmentWithoutAStateController() throws {
        let environmentState = ThomasEnvironmentState(values: values(), conditions: try sizeConditions())
        let state = ThomasState(environmentState: environmentState) { _ in }
        #expect(environment(state) == environmentState.values.json)

        let compact = try predicate(#"{"scope": ["$environment", "conditions", "size"], "value": {"equals": "compact"}}"#)
        #expect(compact.evaluate(json: state.state))
    }

    @Test
    func scopedStateCarriesEnvironment() {
        let environmentState = ThomasEnvironmentState(values: values())
        let root = ThomasState(environmentState: environmentState) { _ in }
        let scoped = root.with(mutableState: ThomasState.MutableState())

        environmentState.update(traits: traits(darkMode: true))
        #expect(environment(scoped) == values(darkMode: true).json)
    }

    @Test
    func setStateOnEnvironmentIsIgnored() async {
        let mutableState = ThomasState.MutableState(initialState: ["$environment": "stale"])
        let state = ThomasState(
            mutableState: mutableState,
            environmentState: ThomasEnvironmentState(values: values())
        ) { _ in }

        let setEnvironment = ThomasStateAction.setState(.init(key: "$environment", value: "set", ttl: nil))
        await state.process(outcomes: [setEnvironment.asOutcome])

        #expect(environment(state) == values().json)
        #expect(mutableState.persistentStateSnapshot()["$environment"] == nil)
    }

    @Test
    func traitChangesPublishAtOnce() {
        let environmentState = ThomasEnvironmentState(values: values(), taskSleeper: GatedTaskSleeper())

        environmentState.update(traits: traits(textScale: 1.5))
        #expect(environmentState.values == values(textScale: 1.5))

        environmentState.update(traits: traits(darkMode: true, textScale: 1.5))
        #expect(environmentState.values == values(darkMode: true, textScale: 1.5))
    }

    @Test
    func resizePublishesFirstAndLastSize() async {
        let sleeper = GatedTaskSleeper()
        let environmentState = ThomasEnvironmentState(values: values(), taskSleeper: sleeper)

        environmentState.update(window: CGSize(width: 400, height: 844), safeWindow: CGSize(width: 400, height: 844))
        #expect(environmentState.values.geometry.window?.width == 400)

        environmentState.update(window: CGSize(width: 410, height: 844), safeWindow: CGSize(width: 410, height: 844))
        environmentState.update(window: CGSize(width: 420, height: 844), safeWindow: CGSize(width: 420, height: 844))
        #expect(environmentState.values.geometry.window?.width == 400)

        await sleeper.release()
        #expect(environmentState.values.geometry.window?.width == 420)
    }

    @Test
    func traitChangeDuringResizeCarriesTheLatestSize() {
        let environmentState = ThomasEnvironmentState(values: values(), taskSleeper: GatedTaskSleeper())

        environmentState.update(window: CGSize(width: 400, height: 844), safeWindow: CGSize(width: 400, height: 844))
        environmentState.update(window: CGSize(width: 410, height: 844), safeWindow: CGSize(width: 410, height: 844))
        environmentState.update(traits: traits(darkMode: true))

        #expect(environmentState.values.traits == traits(darkMode: true))
        #expect(environmentState.values.geometry.window == CGSize(width: 410, height: 844))
    }

    @Test
    func emptySizesAreIgnored() {
        let environmentState = ThomasEnvironmentState(values: values(), taskSleeper: GatedTaskSleeper())
        environmentState.update(window: .zero, safeWindow: .zero)
        environmentState.update(frame: .init(width: 0, height: 0))
        #expect(environmentState.values == values())
    }

    @Test
    func sizesReportedDuringACooldownPublishTogether() async {
        let sleeper = GatedTaskSleeper()
        let environmentState = ThomasEnvironmentState(values: values(), taskSleeper: sleeper)

        environmentState.update(window: CGSize(width: 400, height: 844), safeWindow: CGSize(width: 400, height: 763))
        environmentState.update(window: CGSize(width: 410, height: 844), safeWindow: CGSize(width: 410, height: 763))
        environmentState.update(frame: .init(width: 360, height: 500))
        #expect(environmentState.values.geometry.window?.width == 400)
        #expect(environmentState.values.geometry.frame == nil)

        await sleeper.release()
        #expect(environmentState.values.geometry == .init(
            window: CGSize(width: 410, height: 844),
            safeWindow: CGSize(width: 410, height: 763),
            frame: .init(width: 360, height: 500)
        ))
    }
}
