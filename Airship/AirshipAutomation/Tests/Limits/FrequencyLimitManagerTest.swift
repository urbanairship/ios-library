/* Copyright Airship and Contributors */

import Testing
import Foundation
@testable @_spi(AirshipInternal) import AirshipAutomation
@testable import AirshipCore

struct FrequencyLimitManagerTest {

    private let manager: FrequencyLimitManager
    private let date: UATestDate = UATestDate(offset: 0, dateOverride: Date(timeIntervalSince1970: 0))
    private let store: FrequencyLimitStore = FrequencyLimitStore(
        appKey: UUID().uuidString,
        inMemory: true
    )

    init() {
        self.manager = FrequencyLimitManager(
            dataStore: self.store,
            date: self.date
        )
    }
    
    @MainActor
    @Test
    func testGetCheckerNoLimits() async throws {
        let frequencyChecker = try await self.manager.getFrequencyChecker(constraintIDs: [])
        #expect(frequencyChecker.checkAndIncrement())
        #expect(!(frequencyChecker.isOverLimit))
    }
    
    @MainActor
    @Test
    func testSingleChecker() async throws {
        let constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2
        )

        try await self.manager.setConstraints([constraint])

        var constraints = try await self.store.fetchConstraints()
        #expect(constraints.count == 1)
        
        let startDate = Date(timeIntervalSince1970: 0)
        self.date.dateOverride = startDate
            
        let frequencyChecker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])

        constraints = try await self.store.fetchConstraints()
        #expect(constraints.count == 1)
        #expect(!(frequencyChecker.isOverLimit))
        #expect(frequencyChecker.checkAndIncrement())

        self.date.offset = 1
        #expect(!(frequencyChecker.isOverLimit))
        #expect(frequencyChecker.checkAndIncrement())

        // We should now be over the limit
        #expect(frequencyChecker.isOverLimit)
        #expect(!(frequencyChecker.checkAndIncrement()))

        // After the range has passed we should no longer be over the limit
        self.date.offset = 11
        #expect(!(frequencyChecker.isOverLimit))

        // One more increment should push us back over the limit
        #expect(frequencyChecker.checkAndIncrement())
        #expect(frequencyChecker.isOverLimit)

        await self.manager.writePending()

        let occurrences = try await self.store.fetchConstraints(["foo"])
            .first!
            .occurrences
            .map { occurence in
                occurence.timestamp.timeIntervalSince1970
            }

        // We should only have three occurrences, since the last check and increment should be a no-op
        #expect(Set<Double>([0, 1, 11]) == Set(occurrences))
    }

    @MainActor
    @Test
    func testMultipleCheckers() async throws {
        let constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2
        )

        try await self.manager.setConstraints([constraint])

        let checker1 = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])
        let checker2 = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])

        let constraints = try await self.store.fetchConstraints()
        #expect(constraints.count == 1)

        #expect(!(checker1.isOverLimit))
        #expect(!(checker2.isOverLimit))

        #expect(checker1.checkAndIncrement())

        self.date.offset = 1
        #expect(checker2.checkAndIncrement())

        // We should now be over the limit
        #expect(checker1.isOverLimit)
        #expect(checker2.isOverLimit)

        // After the range has passed we should no longer be over the limit
        self.date.offset = 11
        #expect(!(checker1.isOverLimit))
        #expect(!(checker2.isOverLimit))

        // The first check and increment should succeed, and the next should put us back over the limit again
        #expect(checker1.checkAndIncrement())

        self.date.offset = 1
        #expect(!(checker2.checkAndIncrement()))

        await self.manager.writePending()

        let occurrences = try await self.store.fetchConstraints(["foo"])
            .first!
            .occurrences
            .map { occurence in
                occurence.timestamp.timeIntervalSince1970
            }

        // We should only have three occurrences, since the last check and increment should be a no-op
        #expect(Set<Double>([0, 1, 11]) == Set(occurrences))
    }

    @MainActor
    @Test
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

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo", "bar"])

        #expect(!(checker.isOverLimit))
        var result = checker.checkAndIncrement()
        #expect(result)

        self.date.offset = 1
        // We should now be violating constraint 2
        #expect(checker.isOverLimit)
        result = checker.checkAndIncrement()
        #expect(!(result))

        self.date.offset = 3
        // We should no longer be violating constraint 2
        #expect(!(checker.isOverLimit))
        result = checker.checkAndIncrement()
        #expect(result)

        // We should now be violating constraint 1
        self.date.offset = 9
        #expect(checker.isOverLimit)
        result = checker.checkAndIncrement()
        #expect(!(result))

        // We should now be violating neither constraint
        self.date.offset = 11
        #expect(!(checker.isOverLimit))

        // One more increment should hit the limit
        result = checker.checkAndIncrement()
        #expect(result)
        #expect(checker.isOverLimit)
    }

    @MainActor
    @Test
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

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo", "bar"])

        try await self.manager.setConstraints(
            [
                FrequencyConstraint(
                    identifier: "bar",
                    range: 10,
                    count: 10
                )
            ]
        )

        #expect(checker.checkAndIncrement())
        self.date.offset = 1
        #expect(checker.checkAndIncrement())
        self.date.offset = 1
        #expect(checker.checkAndIncrement())

        await self.manager.writePending()

        // Foo should not exist
        let fooInfo = try await self.store.fetchConstraints(["foo"])
        #expect(fooInfo.count == 0)

        // Bar should have the two occurences
        let barInfo = try await self.store.fetchConstraints(["bar"])
        #expect(barInfo.first?.occurrences.count == 3)
    }

    @MainActor
    @Test
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

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])
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
        #expect(fooInfo.first?.occurrences.count == 0)
    }

    @Test
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

        let checker = try await self.manager.getFrequencyChecker(constraintIDs: ["foo"])
        let result = await checker.checkAndIncrement()
        #expect(result)

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
        #expect(fooInfo.first?.occurrences.count == 1)
    }
    
}
