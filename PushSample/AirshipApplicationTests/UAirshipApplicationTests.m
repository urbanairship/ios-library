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
    UALocationService *location = [UAirship shared].locationService;
    STAssertTrue([location isKindOfClass:[UALocationService class]],nil);
}

- (void)testExceptionForTakeOffOnNotTheMainThread {
    
    [UAirship land]; // Reset the shared instance
    
    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(takeOffException) object:nil];
    [thread start];
    do {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
    } while(![thread isFinished]);
    [thread release];
    
    [UAirship takeOff:[NSMutableDictionary dictionary]]; // Recreate the shared instance
}

// A helper method that calls takeOff; intended to be called from a background thread.
- (void)takeOffException {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSLog(@"Testing [UAirship takeOff:nil] in background thread %@", [NSThread currentThread]); 
    STAssertFalse([[NSThread currentThread] isMainThread], @"Test invalid, running on the main thread");
    STAssertThrowsSpecificNamed(
                                [UAirship takeOff:[NSMutableDictionary dictionary]],
                                NSException, UAirshipTakeOffBackgroundThreadException,
                                @"Calling takeOff on a background thread should throw a UAirshipTakeOffBackgroundThreadException");
    
    [pool drain];
}
@end
