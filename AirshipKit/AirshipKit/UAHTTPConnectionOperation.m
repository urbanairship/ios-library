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

#import "UAHTTPConnectionOperation+Internal.h"
#import "UAGlobal.h"
#import "UAHTTPConnection+Internal.h"

@interface UAHTTPConnectionOperation()

//NSOperation KVO properties

/**
 * Indicates whether the operation is concurrent.
 *
 * Note that in this case, "concurrent" is used in the sense employed by NSOperation and NSOperationQueue,
 * and is not directly related to whether operations executed in a queue are run on a separate thread.
 * Rather, "concurrent" here means something more akin to "asynchronous".
 * See Apple's documentation for more details:
 * 
 * http://developer.apple.com/library/ios/#documentation/cocoa/reference/NSOperation_class/Reference/Reference.html
 */
@property (nonatomic, assign) BOOL isConcurrent;

/**
 * Indicates whether the operation is currently executing.
 */
@property (nonatomic, assign) BOOL isExecuting;

/**
 * Indicates whether the operation has finished.
 */
@property (nonatomic, assign) BOOL isFinished;

//Additional private state

/**
 * The request to be executed.
 */
@property (nonatomic, strong) UAHTTPRequest *request;

/**
 * The UAHTTPConnectionSuccessBlock to be executed if the connection is successful.
 */
@property (nonatomic, copy) UAHTTPConnectionSuccessBlock successBlock;

/**
 * The UAHTTPConnectionFailureBlock to be executed if the connection is unsuccessful.
 */
@property (nonatomic, copy) UAHTTPConnectionFailureBlock failureBlock;

/**
 * The actual HTTP connection, created and run once the operation begins execution.
 */
@property (nonatomic, strong, nullable) UAHTTPConnection *connection;

@end

@implementation UAHTTPConnectionOperation

- (instancetype)initWithRequest:(UAHTTPRequest *)request
               onSuccess:(UAHTTPConnectionSuccessBlock)successBlock
               onFailure:(UAHTTPConnectionFailureBlock)failureBlock {

    self = [super init];
    if (self) {
        self.request = request;
        self.successBlock = successBlock;
        self.failureBlock = failureBlock;
        //setting isConcurrent to YES allows us to wrap an otherwise async task and control
        //the executing/finished/cancelled semantics granularly.
        self.isConcurrent = YES;
        self.isExecuting = NO;
        self.isFinished = NO;        
    }
    return self;
}

+ (instancetype)operationWithRequest:(UAHTTPRequest *)request
                 onSuccess:(UAHTTPConnectionSuccessBlock)successBlock
                 onFailure:(UAHTTPConnectionFailureBlock)failureBlock {

    return [[self alloc] initWithRequest:request
                               onSuccess:successBlock
                               onFailure:failureBlock];
}

- (void)setIsExecuting:(BOOL)isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)setIsConcurrent:(BOOL)isConcurrent {
    [self willChangeValueForKey:@"isConcurrent"];
    _isConcurrent = isConcurrent;
    [self didChangeValueForKey:@"isConcurrent"];
}

- (void)setIsFinished:(BOOL)isFinished {
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)cancel {
    //the super call affects the isCancelled KVO value, synchronize to avoid a race
    @synchronized(self) {
        [super cancel];

        [self.connection cancel];

        if (self.isExecuting) {
            [self finish];
        }
    }
}

- (void)start {

    UAHTTPConnectionSuccessBlock onConnectionSuccess = ^(UAHTTPRequest *request) {
        if (self.successBlock) {
            self.successBlock(request);
        }

        if (!self.isFinished) {
            [self finish];
        }
    };

    UAHTTPConnectionFailureBlock onConnectionFailure = ^(UAHTTPRequest *request) {
        if (self.failureBlock) {
            self.failureBlock(request);
        }
        if (!self.isFinished) {
            [self finish];
        }
    };

    //synchronize change to the isExecuting KVO value
    @synchronized(self) {
        //we may have already been cancelled at this point, in which case finish and retrun
        if (self.isCancelled) {
            [self finish];
            return;
        }
        self.isExecuting = YES;

        self.connection = [UAHTTPConnection connectionWithRequest:self.request successBlock:onConnectionSuccess failureBlock:onConnectionFailure];
        self.connection.delegateQueue = [NSOperationQueue mainQueue];
        [self.connection start];
    }
}

- (void)cleanup {
    self.connection = nil;
    self.failureBlock = nil;
    self.successBlock = nil;
}

- (void)finish {
    [self cleanup];
    self.isExecuting = NO;
    self.isFinished = YES;
}

- (void)dealloc {
    [self.connection cancel];
}

@end
