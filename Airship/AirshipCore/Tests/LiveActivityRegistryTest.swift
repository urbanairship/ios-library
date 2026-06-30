/* Copyright Airship and Contributors */

import Testing

@testable import AirshipCore
import Foundation

@Suite(.timeLimit(.minutes(1)))
struct LiveActivityRegistryTest {

    let date: UATestDate = UATestDate()
    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    fileprivate let tracker = TestPushToStartTracker()

    init() {
        self.date.dateOverride = Date(timeIntervalSince1970: 0)
    }

    private func makeRegistry() -> LiveActivityRegistry {
        LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )
    }

    @Test
    func testAdd() async throws {
        let registry = makeRegistry()
        let activity = TestLiveActivity("foo id")
        await registry.addLiveActivity(activity, name: "foo")

        self.date.offset += 1.0
        activity.pushTokenString = "foo token"

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 1000, 
                token: "foo token"
            )
        )

        self.date.offset += 1.0
        activity.isUpdatable = false

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 2000
            )
        )
    }

    @Test
    func testReplace() async throws {
        let registry = makeRegistry()
        let activityFirst = TestLiveActivity("first id")
        activityFirst.pushTokenString = "first token"

        await registry.addLiveActivity(activityFirst, name: "foo")
        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "first id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "first token"
            )
        )

        let activitySecond = TestLiveActivity("second id")
        await registry.addLiveActivity(activitySecond, name: "foo")

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "first id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0
            )
        )
    }

    @Test
    func testRestore() async throws {
        var registry = makeRegistry()
        var activity = TestLiveActivity("foo id")
        await registry.addLiveActivity(activity, name: "foo")

        // Recreate it
        registry = makeRegistry()
        activity = TestLiveActivity("foo id")

        await registry.restoreTracking(activities: [activity], startTokenTrackers: [])

        activity.pushTokenString = "neat"

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "neat"
            )
        )
    }
    
    @Test
    func testRestoreEmitsStartTokenEvent() async throws {
        var registry = makeRegistry()
        tracker.token = "activity-token"
        
        await registry.restoreTracking(activities: [], startTokenTrackers: [tracker])

        await assertUpdate(registry, LiveActivityUpdate(
            action: .set,
            source: .startToken(attributeType: "TestPushToStartTracker"),
            actionTimeMS: 0,
            token: "activity-token"
        ))

        // Recreate it
        registry = makeRegistry()

        await registry.restoreTracking(activities: [], startTokenTrackers: [])

        await assertUpdate(registry, LiveActivityUpdate(
            action: .remove,
            source: .startToken(attributeType: "TestPushToStartTracker"),
            actionTimeMS: 0
        ))
    }
    
    @Test
    func testRestoreResendsStaleTokens() async throws {
        var registry = makeRegistry()
        tracker.token = "activity-token"

        await registry.restoreTracking(activities: [], startTokenTrackers: [tracker])

        await assertUpdate(registry, LiveActivityUpdate(
            action: .set,
            source: .startToken(attributeType: "TestPushToStartTracker"),
            actionTimeMS: 0,
            token: "activity-token"
        ))

        self.date.offset = 172800 + 2

        // Recreate it
        registry = makeRegistry()

        await registry.restoreTracking(activities: [], startTokenTrackers: [tracker])

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .set,
                source: .startToken(attributeType: "TestPushToStartTracker"),
                actionTimeMS: 172802000,
                token: "activity-token"
            )
        )
    }

    @Test
    func testCleareUntracked() async throws {
        var registry = makeRegistry()
        let activity = TestLiveActivity("foo id")
        activity.pushTokenString = "neat"
        await registry.addLiveActivity(activity, name: "foo")

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "neat"
            )
        )

        // Recreate it
        registry = makeRegistry()

        self.date.offset += 3
        await registry.restoreTracking(activities: [], startTokenTrackers: [])

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 3000
            )
        )
    }

    @Test
    func testCleareUntrackedMaxActionTime() async throws {
        var registry = makeRegistry()
        let activity = TestLiveActivity("foo id")
        activity.pushTokenString = "neat"
        await registry.addLiveActivity(activity, name: "foo")

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "neat"
            )
        )

        // Recreate it
        registry = makeRegistry()

        self.date.offset += 28800.1  // 8 hours and .1 second
        await registry.restoreTracking(activities: [], startTokenTrackers: [])

        await assertUpdate(
            registry,
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 2_880_0000  // 8 hours
            )
        )
    }

    @Test
    @available(iOS 16.1, *)
    func testRegistrationStatusByID() async {
        let registry = makeRegistry()
        // notTracked
        var updates = registry.registrationUpdates(name: nil, id: "some-id").makeAsyncIterator()
        var status = await updates.next()
        #expect(status == .notTracked)

        let activity = TestLiveActivity("some-id")
        await registry.addLiveActivity(activity, name: "some-name")

        // pending
        status = await updates.next()
        #expect(status == .pending)

        await registry.updatesProcessed(
            updates: [
                LiveActivityUpdate(
                    action: .set,
                    source: .liveActivity(id: "some-id", name: "some-name", startTimeMS: 100),
                    actionTimeMS: 100
                )
            ]
        )

        // registered
        status = await updates.next()
        #expect(status == .registered)

        // Register an activity over it
        let otherActivity = TestLiveActivity("some-other-id")
        await registry.addLiveActivity(otherActivity, name: "some-name")

        // notTracked since its by ID and has been replaced
        status = await updates.next()
        #expect(status == .notTracked)
    }

    @Test
    @available(iOS 16.1, *)
    func testRegistrationStatusByName() async {
        let registry = makeRegistry()
        // notTracked
        var updates = registry.registrationUpdates(name: "some-name", id: nil).makeAsyncIterator()
        var status = await updates.next()
        #expect(status == .notTracked)

        let activity = TestLiveActivity("some-id")
        await registry.addLiveActivity(activity, name: "some-name")

        // pending
        status = await updates.next()
        #expect(status == .pending)

        await registry.updatesProcessed(
            updates: [
                LiveActivityUpdate(
                    action: .set,
                    source: .liveActivity(id: "some-id", name: "some-name", startTimeMS: 100),
                    actionTimeMS: 100
                )
            ]
        )

        // registered
        status = await updates.next()
        #expect(status == .registered)

        let otherActivity = TestLiveActivity("some-other-id")
        await registry.addLiveActivity(otherActivity, name: "some-name")

        // pending since its by name
        status = await updates.next()
        #expect(status == .pending)
    }

    @Test
    @available(iOS 16.1, *)
    func testRegistrationStatus() async {
        let registry = makeRegistry()
        // Not tracked
        var updates = registry.registrationUpdates(name: "some-name", id: nil).makeAsyncIterator()
        var status = await updates.next()
        #expect(status == .notTracked)

        let activity = TestLiveActivity("some-id")
        await registry.addLiveActivity(activity, name: "some-name")

        // pending
        status = await updates.next()
        #expect(status == .pending)

        await registry.updatesProcessed(
            updates: [
                LiveActivityUpdate(
                    action: .set,
                    source: .liveActivity(id: "some-id", name: "some-name", startTimeMS: 100),
                    actionTimeMS: 100
                )
            ]
        )

        // registered
        status = await updates.next()
        #expect(status == .registered)
    }


    @Test
    @available(iOS 16.1, *)
    func testStatusPending() async {
        let registry = makeRegistry()
        let activity = TestLiveActivity("foo id")
        await registry.addLiveActivity(activity, name: "foo")

        var updates = registry.registrationUpdates(name: "foo", id: nil).makeAsyncIterator()
        let status = await updates.next()
        #expect(status == .pending)
    }
    
    @Test
    func testLiveUpdateV1Restoring() throws {
        let payload: [String: Any] = [
            "id": "test-id",
            "action": "set",
            "name": "update-name",
            "token": "some token",
            "action_ts_ms": 123,
            "start_ts_ms": 100
        ]
        
        let updateToken = try decode(payload)

        let expected = LiveActivityUpdate(
            action: .set,
            source: .liveActivity(
                id: "test-id",
                name: "update-name",
                startTimeMS: 100
            ),
            actionTimeMS: 123,
            token: "some token"
        )

        #expect(updateToken == expected)
    }
    
    @Test
    func testLiveUpdateV2RestoringUpdateToken() throws {
        let payload: [String: Any] = [
            "id": "test-id",
            "action": "set",
            "name": "update-name",
            "token": "some token",
            "action_ts_ms": 123,
            "start_ts_ms": 100,
            "type": "update_token"
        ]

        let updateToken = try decode(payload)
        let expected = LiveActivityUpdate(
            action: .set,
            source: .liveActivity(
                id: "test-id",
                name: "update-name",
                startTimeMS: 100
            ),
            actionTimeMS: 123,
            token: "some token"
        )

        #expect(updateToken == expected)
    }

    @Test
    func testLiveUpdateV2RestoringStartToken() throws {
        let payload: [String: Any] = [
            "action": "set",
            "token": "some token",
            "action_ts_ms": 123,
            "attributes_type": "test-attribute types",
            "type": "start_token"
        ]

        let startToken = try decode(payload)

        let expected = LiveActivityUpdate(
            action: .set,
            source: .startToken(attributeType: "test-attribute types"),
            actionTimeMS: 123,
            token: "some token"
        )

        #expect(startToken == expected)
    }
    
    private func decode(_ dict: [String: Any]) throws -> LiveActivityUpdate {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LiveActivityUpdate.self, from: data)
    }

    private func assertUpdate(
        _ registry: LiveActivityRegistry,
        _ update: LiveActivityUpdate,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        let next = await registry.updates.first(where: { _ in true })
        #expect(update == next, sourceLocation: sourceLocation)
    }
}

/// Tried to match as closely as I coudl to the real object
private final class TestLiveActivity: LiveActivityProtocol, @unchecked Sendable {
    let id: String
    var isUpdatable: Bool = true {
        didSet {
            statusUpdatesContinuation.yield(isUpdatable)
        }
    }
    var pushTokenString: String? {
        didSet {
            pushTokenUpdatesContinuation.yield(pushTokenString ?? "")
        }
    }

    private let pushTokenUpdates: AsyncStream<String>
    private let pushTokenUpdatesContinuation: AsyncStream<String>.Continuation
    private let statusUpdates: AsyncStream<Bool>
    private let statusUpdatesContinuation: AsyncStream<Bool>.Continuation

    init(_ id: String) {
        self.id = id

        var pushTokenUpdatesEscapee: AsyncStream<String>.Continuation? = nil
        self.pushTokenUpdates = AsyncStream { continuation in
            pushTokenUpdatesEscapee = continuation
        }
        self.pushTokenUpdatesContinuation = pushTokenUpdatesEscapee!

        var statusUpdateEscapee: AsyncStream<Bool>.Continuation? = nil
        self.statusUpdates = AsyncStream { continuation in
            statusUpdateEscapee = continuation
        }
        self.statusUpdatesContinuation = statusUpdateEscapee!
    }

    func track(tokenUpdates: @Sendable @escaping (String) async -> Void) async {
        guard self.isUpdatable else {
            return
        }

        let task = Task {
            for await token in self.pushTokenUpdates {
                try Task.checkCancellation()
                await tokenUpdates(token)
            }
        }

        if let token = self.pushTokenString {
            await tokenUpdates(token)
        }

        for await update in self.statusUpdates {
            if !update || Task.isCancelled {
                task.cancel()
                break
            }
        }
    }
}

fileprivate final class TestPushToStartTracker: LiveActivityPushToStartTrackerProtocol, @unchecked Sendable {
    var attributeType: String { return String(describing: Self.self) }
    
    var token: String?
    
    func track(tokenUpdates: @escaping @Sendable (String) async -> Void) async {
        guard let token = self.token else { return }
        await tokenUpdates(token)
    }
}
