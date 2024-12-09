/* Copyright Airship and Contributors */

import XCTest

@testable import AirshipCore

final class LiveActivityRegistryTest: XCTestCase {

    let date: UATestDate = UATestDate()
    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    var registry: LiveActivityRegistry!
    var tracker = TestPushToStartTracker()

    override func setUpWithError() throws {
        self.date.dateOverride = Date(timeIntervalSince1970: 0)

        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )
    }

    func testAdd() async throws {
        let activity = TestLiveActivity("foo id")
        await self.registry.addLiveActivity(activity, name: "foo")

        self.date.offset += 1.0
        activity.pushTokenString = "foo token"

        await assertUpdate(
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
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 2000
            )
        )
    }

    func testReplace() async throws {
        let activityFirst = TestLiveActivity("first id")
        activityFirst.pushTokenString = "first token"

        await self.registry.addLiveActivity(activityFirst, name: "foo")
        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "first id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "first token"
            )
        )

        let activitySecond = TestLiveActivity("second id")
        await self.registry.addLiveActivity(activitySecond, name: "foo")

        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "first id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0
            )
        )
    }

    func testRestore() async throws {
        var activity = TestLiveActivity("foo id")
        await self.registry.addLiveActivity(activity, name: "foo")

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )
        activity = TestLiveActivity("foo id")

        await self.registry.restoreTracking(activities: [activity], startTokenTrackers: [])

        activity.pushTokenString = "neat"

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "neat"
            )
        )
    }
    
    func testRestoreEmitsStartTokenEvent() async throws {
        tracker.token = "activity-token"
        
        await self.registry.restoreTracking(activities: [], startTokenTrackers: [tracker])

        await assertUpdate(LiveActivityUpdate(
            action: .set,
            source: .startToken(attributeType: "TestPushToStartTracker"),
            actionTimeMS: 0,
            token: "activity-token"
        ))

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )

        await self.registry.restoreTracking(activities: [], startTokenTrackers: [])

        await assertUpdate(LiveActivityUpdate(
            action: .remove,
            source: .startToken(attributeType: "TestPushToStartTracker"),
            actionTimeMS: 0
        ))
    }
    
    func testRestoreResendsStaleTokens() async throws {
        tracker.token = "activity-token"

        await self.registry.restoreTracking(activities: [], startTokenTrackers: [tracker])

        await assertUpdate(LiveActivityUpdate(
            action: .set,
            source: .startToken(attributeType: "TestPushToStartTracker"),
            actionTimeMS: 0,
            token: "activity-token"
        ))

        self.date.offset = 172800 + 2

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )

        await self.registry.restoreTracking(activities: [], startTokenTrackers: [tracker])

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                source: .startToken(attributeType: "TestPushToStartTracker"),
                actionTimeMS: 172802000,
                token: "activity-token"
            )
        )
    }

    func testCleareUntracked() async throws {
        let activity = TestLiveActivity("foo id")
        activity.pushTokenString = "neat"
        await self.registry.addLiveActivity(activity, name: "foo")

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "neat"
            )
        )

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )

        self.date.offset += 3
        await self.registry.restoreTracking(activities: [], startTokenTrackers: [])

        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 3000
            )
        )
    }

    func testCleareUntrackedMaxActionTime() async throws {
        let activity = TestLiveActivity("foo id")
        activity.pushTokenString = "neat"
        await self.registry.addLiveActivity(activity, name: "foo")

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 0,
                token: "neat"
            )
        )

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )

        self.date.offset += 28800.1  // 8 hours and .1 second
        await self.registry.restoreTracking(activities: [], startTokenTrackers: [])

        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                source: .liveActivity(id: "foo id", name: "foo", startTimeMS: 0),
                actionTimeMS: 2_880_0000  // 8 hours
            )
        )
    }

    @available(iOS 16.1, *)
    public func testRegistrationStatusByID() async {
        // notTracked
        var updates = registry.registrationUpdates(name: nil, id: "some-id").makeAsyncIterator()
        var status = await updates.next()
        XCTAssertEqual(status, .notTracked)

        let activity = TestLiveActivity("some-id")
        await self.registry.addLiveActivity(activity, name: "some-name")

        // pending
        status = await updates.next()
        XCTAssertEqual(status, .pending)

        await self.registry.updatesProcessed(
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
        XCTAssertEqual(status, .registered)

        // Register an activity over it
        let otherActivity = TestLiveActivity("some-other-id")
        await self.registry.addLiveActivity(otherActivity, name: "some-name")

        // notTracked since its by ID and has been replaced
        status = await updates.next()
        XCTAssertEqual(status, .notTracked)
    }

    @available(iOS 16.1, *)
    public func testRegistrationStatusByName() async {
        // notTracked
        var updates = registry.registrationUpdates(name: "some-name", id: nil).makeAsyncIterator()
        var status = await updates.next()
        XCTAssertEqual(status, .notTracked)

        let activity = TestLiveActivity("some-id")
        await self.registry.addLiveActivity(activity, name: "some-name")

        // pending
        status = await updates.next()
        XCTAssertEqual(status, .pending)

        await self.registry.updatesProcessed(
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
        XCTAssertEqual(status, .registered)

        let otherActivity = TestLiveActivity("some-other-id")
        await self.registry.addLiveActivity(otherActivity, name: "some-name")

        // pending since its by name
        status = await updates.next()
        XCTAssertEqual(status, .pending)
    }

    @available(iOS 16.1, *)
    public func testRegistrationStatus() async {
        // Not tracked
        var updates = registry.registrationUpdates(name: "some-name", id: nil).makeAsyncIterator()
        var status = await updates.next()
        XCTAssertEqual(status, .notTracked)

        let activity = TestLiveActivity("some-id")
        await self.registry.addLiveActivity(activity, name: "some-name")

        // pending
        status = await updates.next()
        XCTAssertEqual(status, .pending)

        await self.registry.updatesProcessed(
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
        XCTAssertEqual(status, .registered)
    }


    @available(iOS 16.1, *)
    public func testStatusPending() async {
        let activity = TestLiveActivity("foo id")
        await self.registry.addLiveActivity(activity, name: "foo")

        var updates = registry.registrationUpdates(name: "foo", id: nil).makeAsyncIterator()
        let status = await updates.next()
        XCTAssertEqual(status, .pending)
    }
    
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

        XCTAssertEqual(updateToken, expected)
    }
    
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

        XCTAssertEqual(updateToken, expected)
    }

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

        XCTAssertEqual(startToken, expected)
    }
    
    private func decode(_ dict: [String: Any]) throws -> LiveActivityUpdate {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(LiveActivityUpdate.self, from: data)
    }

    private func assertUpdate(
        _ update: LiveActivityUpdate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let next = await self.registry.updates.first(where: { _ in true })
        XCTAssertEqual(update, next, file: file, line: line)
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

final class TestPushToStartTracker: LiveActivityPushToStartTrackerProtocol, @unchecked Sendable {
    var attributeType: String { return String(describing: Self.self) }
    
    var token: String?
    
    func track(tokenUpdates: @escaping @Sendable (String) async -> Void) async {
        guard let token = self.token else { return }
        await tokenUpdates(token)
    }
}
