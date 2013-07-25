/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import <SenTestingKit/SenTestingKit.h>

#import "UAirship+Internal.h"
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
    
    [UAirship takeOff]; // Recreate the shared instance
}

// A helper method that calls takeOff; intended to be called from a background thread.
- (void)takeOffException {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSLog(@"Testing [UAirship takeOff:nil] in background thread %@", [NSThread currentThread]); 
    STAssertFalse([[NSThread currentThread] isMainThread], @"Test invalid, running on the main thread");
    STAssertThrowsSpecificNamed(
                                [UAirship takeOff],
                                NSException, UAirshipTakeOffBackgroundThreadException,
                                @"Calling takeOff on a background thread should throw a UAirshipTakeOffBackgroundThreadException");
    
    [pool drain];
}
@end
