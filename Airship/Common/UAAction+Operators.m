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


#import "UAAction+Operators.h"
#import "UAAction+Internal.h"
#import "UAGlobal.h"

@implementation UAAction (Operators)

- (UAAction *)bind:(UAActionBindBlock)bindBlock {
    if (!bindBlock) {
        return self;
    }

    return bindBlock(^(UAActionArguments *args, UAActionCompletionHandler handler) {
        [self runWithArguments:args withCompletionHandler:handler];
    }, ^(UAActionArguments *args){
        return [self acceptsArguments:args];
    });
}

- (UAAction *)lift:(UAActionLiftBlock)actionLiftBlock transformingPredicate:(UAActionPredicateLiftBlock)predicateLiftBlock {
    if (!actionLiftBlock || !predicateLiftBlock) {
        return self;
    }
    return [self bind:^(UAActionBlock actionBlock, UAActionPredicate predicate){
        UAAction *aggregate = [UAAction actionWithBlock:^(UAActionArguments *args, UAActionCompletionHandler handler){
            actionLiftBlock(actionBlock)(args, handler);
        } acceptingArguments:^(UAActionArguments *args){
            return predicateLiftBlock(predicate)(args);
        }];
        return aggregate;
    }];
}

- (UAAction *)lift:(UAActionLiftBlock)liftBlock {
    if(!liftBlock) {
        return self;
    }
    return [self lift:liftBlock transformingPredicate:^(UAActionPredicate predicate){
        return predicate;
    }];
}

- (UAAction *)continueWith:(UAAction *)next {
    if (!next) {
        return self;
    }
    return [self lift:^(UAActionBlock actionBlock){
        return ^(UAActionArguments *args, UAActionCompletionHandler handler) {
            actionBlock(args, ^(UAActionResult *result){
                if (!result.error) {
                    UAActionArguments *nextArgs = [UAActionArguments argumentsWithValue:result.value withSituation:args.situation];
                    [next runWithArguments:nextArgs withCompletionHandler:^(UAActionResult *nextResult) {
                        handler(nextResult);
                    }];
                } else {
                    handler(result);
                }
            });
        };
    }];
}

- (UAAction *)filter:(UAActionPredicate)filterBlock {
    if (!filterBlock) {
        return self;
    }
    return [self lift:^(UAActionBlock actionBlock){
        return actionBlock;
    } transformingPredicate:^(UAActionPredicate predicate){
        return ^(UAActionArguments *args) {
            if (!filterBlock(args)) {
                return NO;
            }
            return predicate(args);
        };
    }];
}

- (UAAction *)map:(UAActionMapArgumentsBlock)mapArgumentsBlock {
    if (!mapArgumentsBlock) {
        return self;
    }
    return [self lift:^(UAActionBlock actionBlock){
        return ^(UAActionArguments *args, UAActionCompletionHandler handler){
            actionBlock(mapArgumentsBlock(args), handler);
        };
    } transformingPredicate:^(UAActionPredicate predicate){
        return ^(UAActionArguments *args){
            return predicate(mapArgumentsBlock(args));
        };
    }];
}

- (UAAction *)preExecution:(UAActionPreExecutionBlock)preExecutionBlock {
    if (!preExecutionBlock) {
        return self;
    }
    return [self lift:^(UAActionBlock actionBlock){
        return ^(UAActionArguments *args, UAActionCompletionHandler handler){
            preExecutionBlock(args);
            actionBlock(args, handler);
        };
    }];
}

- (UAAction *)postExecution:(UAActionPostExecutionBlock)postExecutionBlock {
    if (!postExecutionBlock) {
        return self;
    }
    return [self lift:^(UAActionBlock actionBlock){
        return ^(UAActionArguments *args, UAActionCompletionHandler handler) {
            actionBlock(args, ^(UAActionResult *result){
                postExecutionBlock(args, result);
                handler(result);
            });
        };
    }];
}

@end
