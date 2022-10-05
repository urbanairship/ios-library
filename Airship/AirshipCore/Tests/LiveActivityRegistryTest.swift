/* Copyright Airship and Contributors */

import XCTest

@testable
import AirshipCore

final class LiveActivityRegistryTest: XCTestCase {

    let date: UATestDate = UATestDate()
    let dataStore = PreferenceDataStore(appKey: UUID().uuidString)
    var registry: LiveActivityRegistry!

    override func setUpWithError() throws {
        self.date.dateOverride = Date(timeIntervalSince1970: 0)

        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )
    }

    func testAdd() async throws  {
        let activity = TestLiveActivity("foo id")
        await self.registry.addLiveActivity(activity, name: "foo")

        self.date.offset += 1.0
        activity.pushTokenString = "foo token"

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                id: "foo id",
                name: "foo",
                token: "foo token",
                actionTimeMS: 1000,
                startTimeMS: 0
            )
        )

        self.date.offset += 1.0
        activity.isActive = false

        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                id: "foo id",
                name: "foo",
                actionTimeMS: 2000,
                startTimeMS: 0
            )
        )
    }

    func testReplace() async throws  {
        let activityFirst = TestLiveActivity("first id")
        activityFirst.pushTokenString = "first token"

        await self.registry.addLiveActivity(activityFirst, name: "foo")
        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                id: "first id",
                name: "foo",
                token: "first token",
                actionTimeMS: 0,
                startTimeMS: 0
            )
        )

        let activitySecond = TestLiveActivity("second id")
        await self.registry.addLiveActivity(activitySecond, name: "foo")

        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                id: "first id",
                name: "foo",
                actionTimeMS: 0,
                startTimeMS: 0
            )
        )
    }

    func testRestore() async throws  {
        var activity = TestLiveActivity("foo id")
        await self.registry.addLiveActivity(activity, name: "foo")

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )
        activity = TestLiveActivity("foo id")


        await self.registry.restoreTracking(activities: [activity])
        await self.registry.clearUntracked()

        activity.pushTokenString = "neat"

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                id: "foo id",
                name: "foo",
                token: "neat",
                actionTimeMS: 0,
                startTimeMS: 0
            )
        )
    }

    func testCleareUntracked() async throws  {
        let activity = TestLiveActivity("foo id")
        activity.pushTokenString = "neat"
        await self.registry.addLiveActivity(activity, name: "foo")

        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                id: "foo id",
                name: "foo",
                token: "neat",
                actionTimeMS: 0,
                startTimeMS: 0
            )
        )

        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )

        self.date.offset += 3
        await self.registry.restoreTracking(activities: [])
        await self.registry.clearUntracked()

        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                id: "foo id",
                name: "foo",
                actionTimeMS: 3000,
                startTimeMS: 0
            )
        )
    }
    
    func testCleareUntrackedMaxActionTime() async throws  {
        let activity = TestLiveActivity("foo id")
        activity.pushTokenString = "neat"
        await self.registry.addLiveActivity(activity, name: "foo")
        
        await assertUpdate(
            LiveActivityUpdate(
                action: .set,
                id: "foo id",
                name: "foo",
                token: "neat",
                actionTimeMS: 0,
                startTimeMS: 0
            )
        )
        
        // Recreate it
        self.registry = LiveActivityRegistry(
            dataStore: self.dataStore,
            date: self.date
        )
        
        self.date.offset += 288000.1 // 8 hours and .1 second
        await self.registry.restoreTracking(activities: [])
        await self.registry.clearUntracked()
        
        await assertUpdate(
            LiveActivityUpdate(
                action: .remove,
                id: "foo id",
                name: "foo",
                actionTimeMS: 288000000, // 8 hours
                startTimeMS: 0
            )
        )
    }

    private func assertUpdate(
        _ update: LiveActivityUpdate,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let next = await self.registry.updates.first(where: { _ in true } )
        XCTAssertEqual(update, next, file: file, line: line)
    }
}


/// Tried to match as closely as I coudl to the real object
fileprivate class TestLiveActivity: LiveActivity {
    let id: String
    var isActive: Bool = true {
        didSet {
            statusUpdatesContinuation.yield(isActive)
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

    func track(tokenUpdates: @escaping (String) async -> Void) async {
        guard self.isActive else {
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

