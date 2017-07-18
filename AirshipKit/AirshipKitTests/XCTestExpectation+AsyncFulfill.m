//
// Created by Anton Matosov on 7/14/17.
// Copyright (c) 2017 Urban Airship. All rights reserved.
//

#import "XCTestExpectation+AsyncFulfill.h"

@implementation XCTestExpectation (AsyncFulfill)

- (void)fulfillAsync
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [self fulfill];
    });
}

- (void)fulfillAfter:(NSTimeInterval)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_main_queue(), ^
    {
        [self fulfill];
    });
}

@end
