/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
@testable import AirshipCore

final class FrequencyLimitManagerTest: AirshipBaseTest {

    private var manager: FrequencyLimitManager!
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date(timeIntervalSince1970: 0))
    private let store: FrequencyLimitStore = FrequencyLimitStore(
        name: UUID().uuidString,
        inMemory: true
    )

    override func setUpWithError() throws {
        self.manager = FrequencyLimitManager(
            dataStore: self.store,
            date: self.date
        )
    }
    
    func testGetCheckerNoLimits() async throws {
        let frequencyChecker = try await self.manager.getFrequencyChecker(constraintIDs: [])
        XCTAssertNil(frequencyChecker)
    }
    
    @MainActor
    func testSingleChecker() async throws {
        let constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2
        )

        try await self.manager.upsertConstraint(constraint)

        var constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 1);
        
        let startDate = Date(timeIntervalSince1970: 0)
        self.date.dateOverride = startDate
            
        let frequencyChecker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])!

        constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 1)
        XCTAssertFalse(frequencyChecker.isOverLimit)
        XCTAssertTrue(frequencyChecker.checkAndIncrement())

        self.date.offset = 1
        XCTAssertFalse(frequencyChecker.isOverLimit)
        XCTAssertTrue(frequencyChecker.checkAndIncrement())

        // We should now be over the limit
        XCTAssertTrue(frequencyChecker.isOverLimit)
        XCTAssertFalse(frequencyChecker.checkAndIncrement())

        // After the range has passed we should no longer be over the limit
        self.date.offset = 11
        XCTAssertFalse(frequencyChecker.isOverLimit)

        // One more increment should push us back over the limit
        XCTAssertTrue(frequencyChecker.checkAndIncrement())
        XCTAssertTrue(frequencyChecker.isOverLimit)

        await self.manager.writePending()

        let occurrences = try await self.store.fetchConstraints(["foo"])
            .first!
            .occurrences
            .map { occurence in
                occurence.timestamp.timeIntervalSince1970
            }

        // We should only have three occurrences, since the last check and increment should be a no-op
        XCTAssertEqual(Set<Double>([0, 1, 11]), Set(occurrences))
    }

    @MainActor
    func testMultipleCheckers() async throws {
        let constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2
        )

        try await self.manager.setConstraints([constraint])

        let checker1 = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])!
        let checker2 = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])!

        let constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 1)

        XCTAssertFalse(checker1.isOverLimit)
        XCTAssertFalse(checker2.isOverLimit)

        XCTAssertTrue(checker1.checkAndIncrement())

        self.date.offset = 1
        XCTAssertTrue(checker2.checkAndIncrement())

        // We should now be over the limit
        XCTAssertTrue(checker1.isOverLimit)
        XCTAssertTrue(checker2.isOverLimit)

        // After the range has passed we should no longer be over the limit
        self.date.offset = 11
        XCTAssertFalse(checker1.isOverLimit)
        XCTAssertFalse(checker2.isOverLimit)

        // The first check and increment should succeed, and the next should put us back over the limit again
        XCTAssertTrue(checker1.checkAndIncrement())

        self.date.offset = 1
        XCTAssertFalse(checker2.checkAndIncrement())

        await self.manager.writePending()

        let occurrences = try await self.store.fetchConstraints(["foo"])
            .first!
            .occurrences
            .map { occurence in
                occurence.timestamp.timeIntervalSince1970
            }

        // We should only have three occurrences, since the last check and increment should be a no-op
        XCTAssertEqual(Set<Double>([0, 1, 11]), Set(occurrences))
    }

    @MainActor
    func testMultipleConstraints() async throws {
        let constraint1 = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2
        )

        let constraint2 = FrequencyConstraint(
            identifier: "bar",
            range: 2, count: 1
        )

        try await self.manager.setConstraints([constraint1, constraint2])

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo", "bar"])!

        XCTAssertFalse(checker.isOverLimit)
        var result = checker.checkAndIncrement()
        XCTAssertTrue(result)

        self.date.offset = 1
        // We should now be violating constraint 2
        XCTAssertTrue(checker.isOverLimit)
        result = checker.checkAndIncrement()
        XCTAssertFalse(result)

        self.date.offset = 3
        // We should no longer be violating constraint 2
        XCTAssertFalse(checker.isOverLimit)
        result = checker.checkAndIncrement()
        XCTAssertTrue(result)

        // We should now be violating constraint 1
        self.date.offset = 9
        XCTAssertTrue(checker.isOverLimit)
        result = checker.checkAndIncrement()
        XCTAssertFalse(result)

        // We should now be violating neither constraint
        self.date.offset = 11
        XCTAssertFalse(checker.isOverLimit)

        // One more increment should hit the limit
        result = checker.checkAndIncrement()
        XCTAssertTrue(result)
        XCTAssertTrue(checker.isOverLimit)
    }

    @MainActor
    func testConstraintRemovedMidCheck() async throws {
        let constraint1 = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2
        )

        let constraint2 = FrequencyConstraint(
            identifier: "bar",
            range: 20,
            count: 2
        )

        try await self.manager.setConstraints([constraint1, constraint2])

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo", "bar"])!

        try await self.manager.setConstraints(
            [
                FrequencyConstraint(
                    identifier: "bar",
                    range: 10,
                    count: 10
                )
            ]
        )

        XCTAssertTrue(checker.checkAndIncrement())
        self.date.offset = 1
        XCTAssertTrue(checker.checkAndIncrement())
        self.date.offset = 1
        XCTAssertFalse(checker.checkAndIncrement())

        await self.manager.writePending()

        // Foo should not exist
        let fooInfo = try await self.store.fetchConstraints(["foo"])
        XCTAssertEqual(fooInfo.count, 0)

        // Bar should have the two occurences
        let barInfo = try await self.store.fetchConstraints(["bar"])
        XCTAssertEqual(barInfo.first?.occurrences.count, 2);
    }

    @MainActor
    func testUpdateConstraintRangeClearsOccurrences() async throws {
        try await self.manager.setConstraints(
            [
                FrequencyConstraint(
                    identifier: "foo",
                    range: 10,
                    count: 2
                )
            ]
        )

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])!
        _ = checker.checkAndIncrement()
        await self.manager.writePending()

        try await self.manager.setConstraints(
            [
                FrequencyConstraint(
                    identifier: "foo",
                    range: 20,
                    count: 2
                )
            ]
        )

        await self.manager.writePending()

        let fooInfo = try await self.store.fetchConstraints(["foo"])
        XCTAssertEqual(fooInfo.first?.occurrences.count, 0);
    }

    func testUpdateConstraintCountDoesNotClearCount() async throws {
        try await self.manager.setConstraints(
            [
                FrequencyConstraint(
                    identifier: "foo",
                    range: 10,
                    count: 2
                )
            ]
        )

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])!
        let result = await checker.checkAndIncrement()
        XCTAssertTrue(result)

        try await self.manager.setConstraints(
            [
                FrequencyConstraint(
                    identifier: "foo",
                    range: 10,
                    count: 3
                )
            ]
        )

        await self.manager.writePending()

        let fooInfo = try await self.store.fetchConstraints(["foo"])
        XCTAssertEqual(fooInfo.first?.occurrences.count, 1);
    }
    
}
