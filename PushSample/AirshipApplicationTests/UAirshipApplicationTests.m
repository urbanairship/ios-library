//
//  PushSampleLib - UAirshipTests.m
//  Copyright 2012 Urban Airship. All rights reserved.
//
//  Created by: Matt Hooge
//

#import <SenTestingKit/SenTestingKit.h>
#import "UAirship.h"
#import "UALocationService.h"

@interface UAirshipApplicationTests : SenTestCase 
@end

@implementation UAirshipApplicationTests

// Testing because of lazy instantiation
- (void)testLocationGetSet {
    UAirship *airship = [UAirship shared];
    UALocationService *location = airship.locationService ;
    STAssertTrue([location isKindOfClass:[UALocationService class]],nil);
}

- (void)testExceptionForTakeOffOnNotTheMainThread {
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(takeOffException) object:nil];
    [thread start];
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    } while(![thread isFinished]);
    [thread release];
}

- (void)takeOffException {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"Testing [UAirship takeOff:nil] in background thread %@", [NSThread currentThread]); 
    STAssertFalse([[NSThread currentThread] isMainThread], @"Test invalid, running on the main thread");
    STAssertThrowsSpecificNamed([UAirship takeOff:nil], NSException, UAirshipTakeOffBackgroundThreadException, @"Calling takeOff on a background thread should throw an UAirshipTakeOffBackgroundThreadException");
    [pool drain];
}
@end
