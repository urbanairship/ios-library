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

#import "UADelayOperationTest.h"
#import "UADelayOperation+Internal.h"

@interface UADelayOperationTest()
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation UADelayOperationTest

- (void)setUp {
    [super setUp];
    self.queue = [[NSOperationQueue alloc] init];
    self.queue.maxConcurrentOperationCount = 1;
}

- (void)testDelay {
    __block BOOL finished = NO;
    [self.queue addOperation:[UADelayOperation operationWithDelayInSeconds:1]];
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        finished = YES;
    }]];

    XCTAssertFalse(finished, @"flag should not be set until after delay completes");
    //give it enough time to complete
    sleep(2);
    XCTAssertTrue(finished, @"flag should be set once delay completes");
}

- (void)testCancel {
    __block BOOL finished = NO;
    //add a long running delay
    [self.queue addOperation:[UADelayOperation operationWithDelayInSeconds:20]];
    [self.queue addOperation:[NSBlockOperation blockOperationWithBlock:^{
        finished = YES;
    }]];

    //give it some time to spin things up
    sleep(1);

    XCTAssertTrue(self.queue.operationCount == 2, @"we should have two operations running");
    [self.queue cancelAllOperations];

    //give it some time to wind things down
    sleep(1);

    XCTAssertFalse(finished, @"flag should still be unset");
    XCTAssertTrue(self.queue.operationCount == 0, @"operation count should be zero");
}

- (void)tearDown {
    self.queue = nil;
    [super tearDown];
}


@end
