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

#import "UAAsyncOperation+Internal.h"

@interface UAAsyncOperation()

/**
 * Indicates whether the operation is currently executing.
 */
@property (nonatomic, assign) BOOL isExecuting;

/**
 * Indicates whether the operation has finished.
 */
@property (nonatomic, assign) BOOL isFinished;

/**
 * Block operation to run.
 */
@property (nonatomic, copy) void (^block)(UAAsyncOperation *);
@end

@implementation UAAsyncOperation

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isExecuting = NO;
        self.isFinished = NO;
    }
    return self;
}

- (instancetype)initWithBlock:(void (^)(UAAsyncOperation *))block {
    self = [self init];
    if (self) {
        self.block = block;
    }
    return self;
}

+ (instancetype)operationWithBlock:(void (^)(UAAsyncOperation *))block {
    return [[UAAsyncOperation alloc] initWithBlock:block];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (void)setIsExecuting:(BOOL)isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setIsFinished:(BOOL)isFinished {
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)dealloc {
    self.block = nil;
}

- (void)cancel {
    @synchronized (self) {
        [super cancel];

        if (self.isExecuting) {
            [self finish];
        }
    }
}

- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            [self finish];
            return;
        }

        self.isExecuting = YES;
        [self startAsyncOperation];
    }
}

- (void)startAsyncOperation {
    if (self.block) {
        self.block(self);
    } else {
        [self finish];
    }
}

- (void)finish {
    @synchronized (self) {
        self.block = nil;

        if (!self.isFinished) {
            self.isExecuting = NO;
            self.isFinished = YES;
        }
    }
}

@end

