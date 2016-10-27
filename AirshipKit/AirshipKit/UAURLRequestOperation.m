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

#import "UAURLRequestOperation+Internal.h"


@interface UAURLRequestOperation()


/**
 * Indicates whether the operation is currently executing.
 */
@property (nonatomic, assign) BOOL isExecuting;

/**
 * Indicates whether the operation has finished.
 */
@property (nonatomic, assign) BOOL isFinished;

@property (nonatomic, copy) NSURLSessionTask *task;

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, copy) void (^completionHandler)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error);
@end

@implementation UAURLRequestOperation


- (instancetype)initWithRequest:(NSURLRequest *)request
                       sesssion:(NSURLSession *)session
              completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {

    self = [super init];
    if (self) {
        self.session = session;
        self.request = request;
        self.completionHandler = completionHandler;
        self.isExecuting = NO;
        self.isFinished = NO;
    }
    return self;
}

+ (instancetype)operationWithRequest:(NSURLRequest *)request
                            session:(NSURLSession *)session
                   completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {

    return [[UAURLRequestOperation alloc] initWithRequest:request sesssion:session completionHandler:completionHandler];
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

- (void)cancel {
    //the super call affects the isCancelled KVO value, synchronize to avoid a race
    @synchronized(self) {
        [super cancel];

        [self.task cancel];

        if (self.isExecuting) {
            [self finish];
        }
    }
}

- (void)start {
    // Create the task
    self.task = [self.session dataTaskWithRequest:self.request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        @synchronized (self) {
            if (!self.isCancelled && self.completionHandler) {
                self.completionHandler(data, response, error);
            }

            if (!self.isFinished) {
                [self finish];
            }
        }
    }];

    // Synchronize change to the isExecuting KVO value
    @synchronized(self) {

        // We may have already been cancelled at this point, in which case finish and retrun
        if (self.isCancelled) {
            [self finish];
            return;
        }

        self.isExecuting = YES;

        [self.task resume];
    }
}


- (void)cleanup {
    self.task = nil;
    self.completionHandler = nil;
    self.request = nil;
    self.session = nil;
}

- (void)finish {
    [self cleanup];
    self.isExecuting = NO;
    self.isFinished = YES;
}

- (void)dealloc {
    [self.task cancel];
}

@end

