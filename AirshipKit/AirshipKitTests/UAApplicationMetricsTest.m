/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <XCTest/XCTest.h>
#import "UAApplicationMetrics+Internal.h"
#import "UAPreferenceDataStore+Internal.h"
#import <OCMock/OCMock.h>

@interface UAApplicationMetricsTest : XCTestCase
@property (nonatomic, strong) UAApplicationMetrics *metrics;
@property (nonatomic, strong) id mockDataStore;
@end

@implementation UAApplicationMetricsTest

- (void)setUp {
    [super setUp];

    self.mockDataStore = [OCMockObject niceMockForClass:[UAPreferenceDataStore class]];
    self.metrics = [UAApplicationMetrics applicationMetricsWithDataStore:self.mockDataStore];
}

- (void)tearDown {
    [super tearDown];

    [self.mockDataStore stopMocking];
}

- (void)testApplicationActive {
    // Make date always return our expected date
    NSDate *expectedDate = [NSDate date];
    id mockDate = [OCMockObject mockForClass:[NSDate class]];
    [[[mockDate stub] andReturn:expectedDate] date];

    [[self.mockDataStore expect] setObject:expectedDate forKey:@"UAApplicationMetricLastOpenDate"];

    [self.metrics didBecomeActive];

    [self.mockDataStore verify];

    [mockDate stopMocking];
}

@end
