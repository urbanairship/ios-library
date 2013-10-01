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

NSString * const UASituationLaunchedFromPush = @"com.urbanairship.situation.launched_from_push";
NSString * const UASituationForegroundPush = @"com.urbanairship.situation.foreground_push";
NSString * const UASituationBackgroundPush = @"com.urbanairship.situation.background_push";

@implementation UAAction

- (instancetype)initWithBlock:(UAActionBlock)actionBlock {
    self = [super init];
    if (self) {
        self.actionBlock = actionBlock;
    }

    return self;
}

+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock {
    return [[UAAction alloc] initWithBlock:actionBlock];
}

- (void)runWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    if ([self canPerformWithArguments:arguments]) {
        [self performWithArguments:arguments withCompletionHandler:completionHandler];
    } else {
        //Note: this may be overly noisy -- predicates are a common argument rejection case but
        //not indicative on an error
        UA_LINFO("Action %@ is unable to perfomWithArguments.", [self description]);
        completionHandler([UAActionResult none]);
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    if (self.actionBlock) {
        self.actionBlock(arguments, completionHandler);
    }
}

- (BOOL)canPerformWithArguments:(UAActionArguments *)arguments {
    if (self.predicateBlock) {
        return self.predicateBlock(arguments);
    } else {
        //otherwise default to YES
        return YES;
    }
}

- (instancetype)precedeWith:(UAActionExtraBlock)extraBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        if (extraBlock) {
            extraBlock();
        }
        [self runWithArguments:args withCompletionHandler:^(UAActionResult *result){
            completionHandler(result);
        }];
    }];

    aggregateAction.predicateBlock = ^(UAActionArguments *arguments){
        return [self canPerformWithArguments:arguments];
    };

    return aggregateAction;
}

- (instancetype)followWith:(UAActionExtraBlock)extraBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:^(UAActionResult *result){
            //Note: do we want errors to prevent the block from executing? probably not?
            if (extraBlock){
                extraBlock();
            };
            completionHandler(result);
        }];
    }];

    aggregateAction.predicateBlock = ^(UAActionArguments *args) {
        return [self canPerformWithArguments:args];
    };

    return aggregateAction;
}

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

    aggregateAction.predicateBlock = ^(UAActionArguments *arguments){
        return [self canPerformWithArguments:arguments];
    };

    return aggregateAction;
}

- (instancetype)filter:(UAActionPredicate)predicateBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
        [self runWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.predicateBlock = predicateBlock;

    return aggregateAction;
}

- (instancetype)filterReplace:(UAActionPredicate)predicateBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler completionHandler){
            [self performWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.predicateBlock = predicateBlock;

    return aggregateAction;
}

@end
