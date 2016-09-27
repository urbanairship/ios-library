/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

#import <Foundation/Foundation.h>
#import "UAHTTPConnection+Test.h"
#import "JRSwizzle.h"

static BOOL succeed_ = YES;

@implementation UAHTTPConnection (Test)

+ (void)succeed {
    succeed_ = YES;
}

+ (void)fail {
    succeed_ = NO;
}

+ (void)swizzle {
    [self jr_swizzleMethod:@selector(start) withMethod:@selector(startWithoutIO) error:nil];
}

+ (void)unSwizzle {
    [self jr_swizzleMethod:@selector(startWithoutIO) withMethod:@selector(start) error:nil];
}

- (void)sendResponse:(void (^)(void))block{
    if (self.delegateQueue) {
        [[NSOperationQueue mainQueue] addOperation:[NSBlockOperation blockOperationWithBlock:block]];
    } else {
        block();
    }
}

- (void)sendSuccess {
    [self sendResponse:^{
        [self connectionDidFinishLoading:self.urlConnection];
    }];
}

- (void)sendFailure {
    [self sendResponse:^{
        [self connection:self.urlConnection didFailWithError:[NSError errorWithDomain:@"whatever" code:0 userInfo:nil]];
    }];
}

- (BOOL)startWithoutIO {
    if (succeed_) {
        [self sendSuccess];
    } else {
        [self sendFailure];
    }
    return YES;
}

@end
