//
// Created by Anton Matosov on 7/14/17.
// Copyright (c) 2017 Urban Airship. All rights reserved.
//

#import <XCTest/XCTest.h>;

@interface XCTestExpectation (AsyncFulfill)

- (void)fulfillAsync;
- (void)fulfillAfter:(NSTimeInterval)delay;

@end
