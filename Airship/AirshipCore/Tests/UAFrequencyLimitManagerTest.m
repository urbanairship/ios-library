/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAFrequencyLimitManager+Internal.h"
#import "AirshipTests-Swift.h"

@interface UAFrequencyLimitManagerTest : UAAirshipBaseTest
@property(nonatomic, strong) UAFrequencyLimitManager *manager;
@property(nonatomic, strong) UAFrequencyLimitStore *store;
@property(nonatomic, strong) UATestDate *date;
@end

@implementation UAFrequencyLimitManagerTest

- (void)setUp {
    self.store = [UAFrequencyLimitStore storeWithName:[NSUUID UUID].UUIDString inMemory:YES];
    self.date = [[UATestDate alloc] init];
    self.manager = [UAFrequencyLimitManager managerWithDataStore:self.store
                                                            date:self.date
                                                      dispatcher:[[UATestDispatcher alloc] init]];
}

- (void)tearDown {
    [self.store shutDown];
    [super tearDown];
}

- (void)testGetCheckerNoLimits {
    XCTestExpectation *finished = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker;

    [self.manager getFrequencyChecker:@[] completionHandler:^(UAFrequencyChecker *c) {
        checker = c;
        [finished fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertFalse(checker.isOverLimit);
    XCTAssertTrue([checker checkAndIncrement]);
    XCTAssertEqual([self.store getConstraints].count, 0);
}

- (void)testSingleChecker {
    XCTestExpectation *finished = [self expectationWithDescription:@"Fetched frequency checker"];

    UAFrequencyConstraint *constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:2];

    XCTestExpectation *updated = [self expectationWithDescription:@"updated limits"];
    [self.manager updateConstraints:@[constraint] completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [updated fulfill];
    }];
    XCTAssertEqual([self.store getConstraints].count, 1);


    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:0];
    self.date.dateOverride = startDate;

    __block UAFrequencyChecker *checker;
    [self.manager getFrequencyChecker:@[@"foo"] completionHandler:^(UAFrequencyChecker *c) {
        checker = c;
        [finished fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertEqual([self.store getConstraints].count, 1);
    XCTAssertFalse(checker.isOverLimit);
    XCTAssertTrue([checker checkAndIncrement]);

    self.date.offset = 1;
    XCTAssertFalse(checker.isOverLimit);
    XCTAssertTrue([checker checkAndIncrement]);

    // We should now be over the limit
    XCTAssertTrue(checker.isOverLimit);
    XCTAssertFalse([checker checkAndIncrement]);

    // After the range has passed we should no longer be over the limit
    self.date.offset = 11;
    XCTAssertFalse(checker.isOverLimit);

    // One more increment should push us back over the limit
    XCTAssertTrue([checker checkAndIncrement]);
    XCTAssertTrue(checker.isOverLimit);

    NSArray<UAOccurrence *> *occurrences = [self.store getOccurrences:@"foo"];

    // We should only have three occurrences, since the last check and increment should be a no-op
    XCTAssertEqual(occurrences.count, 3);

    // Timestamps should be in ascending order
    XCTAssertEqual(occurrences[0].timestamp.timeIntervalSince1970, 0);
    XCTAssertEqual(occurrences[1].timestamp.timeIntervalSince1970, 1);
    XCTAssertEqual(occurrences[2].timestamp.timeIntervalSince1970, 11);
}

- (void)testMultipleCheckers {
    UAFrequencyConstraint *constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:2];
    XCTestExpectation *updated = [self expectationWithDescription:@"updated limits"];
    [self.manager updateConstraints:@[constraint] completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [updated fulfill];
    }];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:0];
    self.date.dateOverride = startDate;

    XCTestExpectation *fetchedChecker1 = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker1;
    [self.manager getFrequencyChecker:@[@"foo"] completionHandler:^(UAFrequencyChecker *checker) {
        checker1 = checker;
        [fetchedChecker1 fulfill];
    }];

    XCTestExpectation *fetchedChecker2 = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker2;
    [self.manager getFrequencyChecker:@[@"foo"] completionHandler:^(UAFrequencyChecker *checker) {
        checker2 = checker;
        [fetchedChecker2 fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertEqual([self.store getConstraints].count, 1);

    XCTAssertFalse([checker1 isOverLimit]);
    XCTAssertFalse([checker2 isOverLimit]);

    XCTAssertTrue([checker1 checkAndIncrement]);

    self.date.offset = 1;
    XCTAssertTrue([checker2 checkAndIncrement]);

    // We should now be over the limit
    XCTAssertTrue([checker1 isOverLimit]);
    XCTAssertTrue([checker2 isOverLimit]);

    // After the range has passed we should no longer be over the limit
    self.date.offset = 11;
    XCTAssertFalse([checker1 isOverLimit]);
    XCTAssertFalse([checker2 isOverLimit]);

    // The first check and increment should succeed, and the next should put us back over the limit again
    XCTAssertTrue([checker1 checkAndIncrement]);
    XCTAssertFalse([checker2 checkAndIncrement]);

    NSArray<UAOccurrence *> *occurrences = [self.store getOccurrences:@"foo"];

    // We should only have three occurrences, since the last check and increment should be a no-op
    XCTAssertEqual(occurrences.count, 3);

    // Timestamps should be in ascending order
    XCTAssertEqual(occurrences[0].timestamp.timeIntervalSince1970, 0);
    XCTAssertEqual(occurrences[1].timestamp.timeIntervalSince1970, 1);
    XCTAssertEqual(occurrences[2].timestamp.timeIntervalSince1970, 11);
}

- (void)testMultipleConstraints {
    UAFrequencyConstraint *constraint1 = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:2];
    UAFrequencyConstraint *constraint2 = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"bar" range:2 count:1];
    
    XCTestExpectation *updated = [self expectationWithDescription:@"updated limits"];
    [self.manager updateConstraints:@[constraint1, constraint2] completionHandler:^(BOOL result) {
        XCTAssertTrue(result);
        [updated fulfill];
    }];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:0];
    self.date.dateOverride = startDate;

    XCTestExpectation *fetchedChecker = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker;
    [self.manager getFrequencyChecker:@[@"foo", @"bar"] completionHandler:^(UAFrequencyChecker *c) {
        checker = c;
        [fetchedChecker fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertFalse(checker.isOverLimit);
    XCTAssertTrue([checker checkAndIncrement]);

    self.date.offset = 1;
    // We should now be violating constraint 2
    XCTAssertTrue(checker.isOverLimit);
    XCTAssertFalse([checker checkAndIncrement]);

    self.date.offset = 3;
    // We should no longer be violating constraint 2
    XCTAssertFalse(checker.isOverLimit);
    XCTAssertTrue([checker checkAndIncrement]);

    // We should now be violating constraint 1
    self.date.offset = 9;
    XCTAssertTrue(checker.isOverLimit);
    XCTAssertFalse([checker checkAndIncrement]);

    // We should now be violating neither constraint
    self.date.offset = 11;
    XCTAssertFalse(checker.isOverLimit);

    // One more increment should hit the limit
    XCTAssertTrue([checker checkAndIncrement]);
    XCTAssertTrue(checker.isOverLimit);
}

- (void)testConstraintRemovedMidCheck {
    UAFrequencyConstraint *constraint1 = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:2];
    UAFrequencyConstraint *constraint2 = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"bar" range:20 count:2];
    [self.manager updateConstraints:@[constraint1, constraint2] completionHandler:^(BOOL updated) {}];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:0];
    self.date.dateOverride = startDate;

    XCTestExpectation *fetchedChecker = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker;
    [self.manager getFrequencyChecker:@[@"foo", @"bar"] completionHandler:^(UAFrequencyChecker *c) {
        checker = c;
        [fetchedChecker fulfill];
    }];

    [self waitForTestExpectations];

    [self.manager updateConstraints:@[[UAFrequencyConstraint frequencyConstraintWithIdentifier:@"bar" range:10 count:2]] completionHandler:^(BOOL updated) {}];

    XCTAssertTrue([checker checkAndIncrement]);
    XCTAssertTrue([checker checkAndIncrement]);
    XCTAssertFalse([checker checkAndIncrement]);

    // Occurrences should be cleared out
    XCTAssertEqual([self.store getOccurrences:@"foo"].count, 0);

    // Still have occurences for bar
    NSArray<UAOccurrence *> *barOccurrences = [self.store getOccurrences:@"bar"];
    XCTAssertEqual(barOccurrences.count, 2);
}

- (void)testUpdateConstraintRangeClearsOccurrences {
    UAFrequencyConstraint *constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:2];
    [self.manager updateConstraints:@[constraint] completionHandler:^(BOOL updated) {}];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:100];
    self.date.dateOverride = startDate;

    XCTestExpectation *fetchedChecker = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker;
    [self.manager getFrequencyChecker:@[@"foo"] completionHandler:^(UAFrequencyChecker *c) {
        checker = c;
        [fetchedChecker fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertTrue([checker checkAndIncrement]);

    constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:11 count:1];
    [self.manager updateConstraints:@[constraint] completionHandler:^(BOOL updated) {}];

    // Occurrences should be cleared out
    XCTAssertEqual([self.store getOccurrences:@"foo"].count, 0);
}

- (void)testUpdateConstraintCountDoesNotClearCount {
    UAFrequencyConstraint *constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:2];
    [self.manager updateConstraints:@[constraint] completionHandler:^(BOOL updated) {}];

    NSDate *startDate = [NSDate dateWithTimeIntervalSince1970:100];
    self.date.dateOverride = startDate;

    XCTestExpectation *fetchedChecker = [self expectationWithDescription:@"Fetched frequency checker"];

    __block UAFrequencyChecker *checker;
    [self.manager getFrequencyChecker:@[@"foo"] completionHandler:^(UAFrequencyChecker *c) {
        checker = c;
        [fetchedChecker fulfill];
    }];

    [self waitForTestExpectations];

    XCTAssertTrue([checker checkAndIncrement]);

    // Update the count
    constraint = [UAFrequencyConstraint frequencyConstraintWithIdentifier:@"foo" range:10 count:5];
    [self.manager updateConstraints:@[constraint] completionHandler:^(BOOL updated) {}];

    // Occurrence should remain
    XCTAssertEqual([self.store getOccurrences:@"foo"].count, 1);
}

@end
