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

#import "UAAction.h"
#import "UAAction+Internal.h"
#import "UAActionResult.h"
#import "UAGlobal.h"


@implementation UAAction

#pragma mark init

- (instancetype)initWithBlock:(UAActionBlock)actionBlock {
    self = [super init];
    if (self) {
        self.actionBlock = actionBlock;
    }

    return self;
}

#pragma mark internal methods

- (void)runWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    if (self.onRunBlock) {
        self.onRunBlock();
    }
    if (![self acceptsArguments:arguments]) {
        UA_LINFO("Action %@ is unable to perform with arguments.", [self description]);
        completionHandler([UAActionResult none]);
    } else {
        [self willPerformWithArguments:arguments];
        [self performWithArguments:arguments withCompletionHandler:^(UAActionResult *result){
            [self didPerformWithArguments:arguments withResult:result];
            completionHandler(result);
        }];
    }
}

#pragma mark core methods

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if (self.acceptsArgumentsBlock) {
        return self.acceptsArgumentsBlock(arguments);
    }
    return YES;
}

- (void)willPerformWithArguments:(UAActionArguments *)arguments {
    //override
}

- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    if (self.actionBlock) {
        self.actionBlock(arguments, completionHandler);
    }
}

- (void)didPerformWithArguments:(UAActionArguments *)arguments withResult:(UAActionResult *)result {
    //override
}

#pragma mark factory methods

+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock {
    return [[UAAction alloc] initWithBlock:actionBlock];
}

#pragma mark operators

- (instancetype)continueWith:(UAAction *)continuationAction {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){

        [self runWithArguments:args withCompletionHandler:^(UAActionResult *selfResult){

            if (!selfResult.error) {
                UAActionArguments *continuationArgs = [UAActionArguments argumentsWithValue:selfResult
                                                                               wihSituation:args.situation];

                [continuationAction runWithArguments:continuationArgs withCompletionHandler:^(UAActionResult *continuationResult){
                    completionHandler(continuationResult);
                }];
            } else {
                //Todo: different log level?
                UA_LINFO(@"%@", selfResult.error.localizedDescription);
                completionHandler(selfResult);
            }
        }];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (instancetype)filter:(UAActionPredicate)filterBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        if (filterBlock && !filterBlock(args)) {
            return NO;
        }
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (instancetype)map:(UAActionMapArgumentsBlock)mapArgumentsBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
        [self runWithArguments:mapArgumentsBlock(args) withCompletionHandler:handler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (instancetype)preExecution:(UAActionPreExecutionBlock)preExecutionBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        if (preExecutionBlock) {
            preExecutionBlock(args);
        }
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (instancetype)postExecution:(UAActionPostExecutionBlock)postExecutionBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:^(UAActionResult *result){
            //Note: do we want errors to prevent the block from executing? probably not?
            if (postExecutionBlock){
                postExecutionBlock(args, result);
            };
            completionHandler(result);
        }];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    return aggregateAction;
}

- (instancetype)take:(NSUInteger)n {
    __block NSUInteger count = 0;

    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *arguments){
        BOOL accepts = [self acceptsArguments:arguments];
        accepts = accepts && count <= n;
        return accepts;
    };

    aggregateAction.onRunBlock = ^{
        count++;
    };

    return aggregateAction;

}

- (instancetype)skip:(NSUInteger)n {

    __block NSUInteger count = 0;
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.acceptsArgumentsBlock = ^(UAActionArguments *arguments){
        BOOL accepts = [self acceptsArguments:arguments];
        accepts = accepts && count > n;
        return accepts;
    };

    aggregateAction.onRunBlock = ^{
        count++;
    };

    return aggregateAction;
}

- (instancetype)nth:(NSUInteger)n {
    return [[self take:n] skip:n-1];
}

- (instancetype)distinctUntilChanged {
    __block id lastValue = nil;

    UAAction *aggregateAction = [[self preExecution:^(UAActionArguments *args){
        lastValue = args.value;
    }] filter:^(UAActionArguments *args){
        return (BOOL)![args.value isEqual:lastValue];
    }];

    return aggregateAction;
}

@end
