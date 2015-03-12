/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UATestSynchronizer.h"

@implementation UATestSynchronizer

- (instancetype)init {
    self = [super init];
    if (self) {
        self.semaphore = dispatch_semaphore_create(0);
        //default to 0.1 seconds per run loop spin
        self.runLoopInterval = 0.1;
        //default to a 2 second timeout
        self.defaultTimeoutInterval = 2;
    }
    return self;
}

- (id)valueForKey:(NSString *)key {
    return [super valueForKey:key];
}

- (id)valueForKeyPath:(NSString *)keyPath {
    return [super valueForKeyPath:keyPath];
}

- (BOOL)waitWithTimeoutInterval:(NSTimeInterval)interval {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    while (dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_NOW)  && [timeoutDate timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:self.runLoopInterval]];
    }
    return [timeoutDate timeIntervalSinceNow] > 0;
}

- (BOOL)wait {
    return [self waitWithTimeoutInterval:self.defaultTimeoutInterval];
}

- (void)continue {
    dispatch_semaphore_signal(self.semaphore);
}

@end
