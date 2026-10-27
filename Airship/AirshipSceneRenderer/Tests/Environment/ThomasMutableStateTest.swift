/* Copyright Airship and Contributors */

import Foundation
import Testing

@testable import AirshipBasement
@testable @_spi(AirshipInternal) import AirshipSceneRenderer

@Suite("Thomas mutable state", .timeLimit(.minutes(1)))
@MainActor
struct ThomasMutableStateTest {

    private func set(_ key: String, _ value: AirshipJSON, on thomasState: ThomasState) async {
        await thomasState.process(outcomes: [
            ThomasStateAction.setState(.init(key: key, value: value, ttl: nil)).asOutcome
        ])
    }

    @Test
    func setKeepsInitialState() async {
        let mutable = ThomasState.MutableState(initialState: ["name": "zak"])
        let thomasState = ThomasState(mutableState: mutable, onStateChange: { _ in })

        await set("next", .bool(true), on: thomasState)

        #expect(mutable.state == ["name": "zak", "next": true])
    }

    @Test
    func setOverridesInitialKey() async {
        let mutable = ThomasState.MutableState(initialState: ["name": "zak", "other": 1])
        let thomasState = ThomasState(mutableState: mutable, onStateChange: { _ in })

        await set("name", .string("sam"), on: thomasState)

        #expect(mutable.state == ["name": "sam", "other": 1])
    }

    @Test
    func initialStateDropsEnvironmentKey() {
        let mutable = ThomasState.MutableState(initialState: ["name": "zak", "$environment": ["foo": true]])

        #expect(mutable.state == ["name": "zak"])
        #expect(mutable.persistentStateSnapshot() == ["name": "zak"])
    }
}
