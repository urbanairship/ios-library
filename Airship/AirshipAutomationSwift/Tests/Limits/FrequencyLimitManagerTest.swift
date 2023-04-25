/* Copyright Airship and Contributors */

import XCTest
@testable import AirshipAutomationSwift
@testable import AirshipCore

final class FrequencyLimitManagerTest: AirshipBaseTest {

    var manager: FrequencyLimitManager?
    var date: UATestDate!
    
    private lazy var store: FrequencyLimitStore = {
        
        let modelURL = AutomationResources.bundle
            .url(
                forResource: "UAFrequencyLimits",
                withExtension: "momd"
            )
        if let modelURL = modelURL {
            let storeName = String(
                format: "Frequency-limits-%@.sqlite",
                self.config.appKey
            )
            let coreData = UACoreData(
                modelURL: modelURL,
                inMemory: true,
                stores: [storeName]
            )
            return FrequencyLimitStore(
                coreData: coreData
            )
        }
        return FrequencyLimitStore(config: self.config)
    }()
    
    override func setUpWithError() throws {
        self.date = UATestDate()
        createManager()
    }
    
    func createManager() {
        self.manager = FrequencyLimitManager(
            dataStore: self.store,
            date: self.date)
    }
    
    func testGetCheckerNoLimits() async throws {
        
        let frequencyChecker = await self.manager?.getFrequencyChecker(constraintIDs: [])
        
        let checker = try XCTUnwrap(frequencyChecker)
        XCTAssertFalse(checker.isOverLimit())
        let result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
        let constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 0)
    }
    
    func testSingleChecker() async throws {
        
        let constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2)
    
        await self.manager?.addOrUpdateConstraints([constraint])
        
        var constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 1);
        
        let startDate = Date(timeIntervalSince1970: 0)
        self.date.dateOverride = startDate
            
        let frequencyChecker = await self.manager?.getFrequencyChecker(constraintIDs: ["foo"])
        let checker = try XCTUnwrap(frequencyChecker)
        
        constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 1)
        XCTAssertFalse(checker.isOverLimit())
        var result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
    
        self.date.offset = 1
        XCTAssertFalse(checker.isOverLimit())
        result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
    
        // We should now be over the limit
        XCTAssertTrue(checker.isOverLimit())
        result = await checker.checkAndIncrement()
        XCTAssertFalse(result)
    
        // After the range has passed we should no longer be over the limit
        self.date.offset = 11
        XCTAssertFalse(checker.isOverLimit())
    
        // One more increment should push us back over the limit
        result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
        XCTAssertTrue(checker.isOverLimit())
    
        let occurrences = try await self.store.fetchOccurrences(
            forConstraintID: "foo"
        )
    
        // We should only have three occurrences, since the last check and increment should be a no-op
        XCTAssertEqual(occurrences.count, 3)
    
        // Timestamps should be in ascending order
        XCTAssertEqual(occurrences[0].timestamp.timeIntervalSince1970, 0)
        XCTAssertEqual(occurrences[1].timestamp.timeIntervalSince1970, 1)
        XCTAssertEqual(occurrences[2].timestamp.timeIntervalSince1970, 11)
    }
    
    
    func testMultipleCheckers() async throws {
        let constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2)
        
        await self.manager?.addOrUpdateConstraints([constraint])

        let startDate = Date(timeIntervalSince1970: 0)
        self.date.dateOverride = startDate
            

        let frequencyChecker1 = await self.manager?.getFrequencyChecker(constraintIDs: ["foo"])
        let checker1 = try XCTUnwrap(frequencyChecker1)
        

        let frequencyChecker2 = await self.manager?.getFrequencyChecker(constraintIDs: ["foo"])
        let checker2 = try XCTUnwrap(frequencyChecker2)

        let constraints = try await self.store.fetchConstraints()
        XCTAssertEqual(constraints.count, 1)

        XCTAssertFalse(checker1.isOverLimit())
        XCTAssertFalse(checker2.isOverLimit())

        var result1 = await checker1.checkAndIncrement()
        XCTAssertTrue(result1)

        self.date.offset = 1
        var result2 = await checker2.checkAndIncrement()
        XCTAssertTrue(result2)

        // We should now be over the limit
        XCTAssertTrue(checker1.isOverLimit())
        XCTAssertTrue(checker2.isOverLimit())

        // After the range has passed we should no longer be over the limit
        self.date.offset = 11
        XCTAssertFalse(checker1.isOverLimit())
        XCTAssertFalse(checker2.isOverLimit())

        // The first check and increment should succeed, and the next should put us back over the limit again
        result1 = await checker1.checkAndIncrement()
        XCTAssertTrue(result1)
        result2 = await checker2.checkAndIncrement()
        XCTAssertFalse(result2)

        let occurrences = try await self.store.fetchOccurrences(forConstraintID: "foo")

        // We should only have three occurrences, since the last check and increment should be a no-op
        XCTAssertEqual(occurrences.count, 3);

        // Timestamps should be in ascending order
        XCTAssertEqual(occurrences[0].timestamp.timeIntervalSince1970, 0);
        XCTAssertEqual(occurrences[1].timestamp.timeIntervalSince1970, 1);
        XCTAssertEqual(occurrences[2].timestamp.timeIntervalSince1970, 11);
    }

    
    func testMultipleConstraints() async throws {
        let constraint1 = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2)
        let constraint2 = FrequencyConstraint(
            identifier: "bar",
            range: 2, count: 1)
        
        await self.manager?.addOrUpdateConstraints([constraint1, constraint2])

        let startDate = Date(timeIntervalSince1970: 0)
        self.date.dateOverride = startDate

        let frequencyChecker = await self.manager?.getFrequencyChecker(constraintIDs: ["foo", "bar"])
        let checker = try XCTUnwrap(frequencyChecker)
        
        XCTAssertFalse(checker.isOverLimit())
        var result = await checker.checkAndIncrement()
        XCTAssertTrue(result)

        self.date.offset = 1
        // We should now be violating constraint 2
        XCTAssertTrue(checker.isOverLimit())
        result = await checker.checkAndIncrement()
        XCTAssertFalse(result)

        self.date.offset = 3
        // We should no longer be violating constraint 2
        XCTAssertFalse(checker.isOverLimit())
        result = await checker.checkAndIncrement()
        XCTAssertTrue(result)

        // We should now be violating constraint 1
        self.date.offset = 9
        XCTAssertTrue(checker.isOverLimit())
        result = await checker.checkAndIncrement()
        XCTAssertFalse(result)

        // We should now be violating neither constraint
        self.date.offset = 11
        XCTAssertFalse(checker.isOverLimit())

        // One more increment should hit the limit
        result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
        XCTAssertTrue(checker.isOverLimit())
    }
    
    
    func testConstraintRemovedMidCheck() async throws {
        let constraint1 = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2)
        let constraint2 = FrequencyConstraint(
            identifier: "bar",
            range: 20,
            count: 2)
        
        await self.manager?.addOrUpdateConstraints([constraint1, constraint2])

        let startDate = Date(timeIntervalSince1970: 0)
        self.date.dateOverride = startDate

        let frequencyChecker = await self.manager?.getFrequencyChecker(constraintIDs: ["foo", "bar"])
        let checker = try XCTUnwrap(frequencyChecker)

        await self.manager?.addOrUpdateConstraints([FrequencyConstraint(
            identifier: "bar",
            range: 10,
            count: 2)])

        var result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
        result = await checker.checkAndIncrement()
        XCTAssertTrue(result)
        result = await checker.checkAndIncrement()
        XCTAssertFalse(result)

        // Occurrences should be cleared out
        let occurrences = try await self.store.fetchOccurrences(forConstraintID: "foo")
        XCTAssertEqual(occurrences.count, 0);

        let barOccurrences = try await self.store.fetchOccurrences(forConstraintID: "bar")
        XCTAssertEqual(barOccurrences.count, 2);
        XCTAssertEqual(barOccurrences[0].timestamp.timeIntervalSince1970, 0);
        XCTAssertEqual(barOccurrences[1].timestamp.timeIntervalSince1970, 0);
    }
    
    
    func testUpdateConstraintRangeClearsOccurrences() async throws {
        var constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 2)
        
        await self.manager?.addOrUpdateConstraints([constraint])

        let startDate = Date(timeIntervalSince1970: 100)
        self.date.dateOverride = startDate

        let frequencyChecker = await self.manager?.getFrequencyChecker(constraintIDs: ["foo"])
        let checker = try XCTUnwrap(frequencyChecker)

        let result = await checker.checkAndIncrement()
        XCTAssertTrue(result)

        constraint = FrequencyConstraint(
            identifier:"foo",
            range:11,
            count:1)
        await self.manager?.addOrUpdateConstraints([constraint])

        // Occurrences should be cleared out
        let occurrences = try await self.store.fetchOccurrences(forConstraintID: "foo")
        XCTAssertEqual(occurrences.count, 0);
    }
    
    
    func testUpdateConstraintCountDoesNotClearCount() async throws {
        var constraint = FrequencyConstraint(
            identifier:"foo",
            range:10,
            count:2)
        
        await self.manager?.addOrUpdateConstraints([constraint])

        let startDate = Date(timeIntervalSince1970: 100)
        self.date.dateOverride = startDate

        let frequencyChecker = await  self.manager?.getFrequencyChecker(constraintIDs: ["foo"])
        let checker = try XCTUnwrap(frequencyChecker)

        let result = await checker.checkAndIncrement()
        XCTAssertTrue(result)

        // Update the count
        constraint = FrequencyConstraint(
            identifier: "foo",
            range: 10,
            count: 5)
        await self.manager?.addOrUpdateConstraints([constraint])

        // Occurrence should remain
        let occurrences = try await self.store.fetchOccurrences(forConstraintID: "foo")
        XCTAssertEqual(occurrences.count, 1);
    }
    
}
