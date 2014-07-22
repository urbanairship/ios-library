/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.

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

NSString * const UAActionOperatorErrorDomain = @"com.urbanairship.actions.operator";


- (UAAction *)bind:(UAActionBindBlock)bindBlock {
    if (!bindBlock) {
        return self;
    }

    UAActionBlock actionBlock = ^(UAActionArguments *args, NSString *actionName, UAActionCompletionHandler handler) {
        [self runWithArguments:args actionName:actionName completionHandler:handler];
    };

    UAActionPredicate acceptsArgumentsBlock = ^(UAActionArguments *args) {
        return [self acceptsArguments:args];
    };

    UAAction *action = bindBlock(actionBlock, acceptsArgumentsBlock);
    return action;
}

- (UAAction *)lift:(UAActionLiftBlock)actionLiftBlock transformingPredicate:(UAActionPredicateLiftBlock)predicateLiftBlock {
    if (!actionLiftBlock || !predicateLiftBlock) {
        return self;
    }

    UAActionBindBlock bindBlock = ^(UAActionBlock actionBlock, UAActionPredicate predicate) {
        UAActionBlock transformedActionBlock = actionLiftBlock(actionBlock);
        UAActionPredicate transformedAcceptsArgumentsBlock = predicateLiftBlock(predicate);

        UAAction *aggregate = [UAAction actionWithBlock:^(UAActionArguments *args, NSString *actionName, UAActionCompletionHandler handler) {
            transformedActionBlock(args, actionName, handler);
        } acceptingArguments: transformedAcceptsArgumentsBlock];

        return aggregate;
    };

    UAAction *action = [self bind:bindBlock];
    return action;
}

- (UAAction *)lift:(UAActionLiftBlock)liftBlock {
    if(!liftBlock) {
        return self;
    }
    return [self lift:liftBlock transformingPredicate:^(UAActionPredicate predicate) {
        return predicate;
    }];
}

- (UAAction *)continueWith:(UAAction *)next {
    if (!next) {
        return self;
    }

    UAActionLiftBlock liftBlock = ^(UAActionBlock actionBlock) {
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, NSString *actionName, UAActionCompletionHandler handler) {
            actionBlock(args, actionName, ^(UAActionResult *result) {
                switch (result.status) {
                    case UAActionStatusCompleted:
                    {
                        UAActionArguments *nextArgs = [UAActionArguments argumentsWithValue:result.value withSituation:args.situation];

                        [next runWithArguments:nextArgs actionName:actionName completionHandler:^(UAActionResult *nextResult) {
                            handler(nextResult);
                        }];

                        break;
                    }
                    case UAActionStatusArgumentsRejected:
                    {
                        NSError *error = [NSError errorWithDomain:UAActionOperatorErrorDomain
                                                             code:UAActionOperatorErrorCodeChildActionRejectedArgs
                                                         userInfo:@{NSLocalizedDescriptionKey : @"Internal action rejected arguments"}];
                        handler([UAActionResult resultWithError:error]);
                        break;
                    }
                    default:
                        handler(result);
                        break;
                }

            });
        };

        return transformedActionBlock;
    };

    return [self lift:liftBlock];
}

- (UAAction *)filter:(UAActionPredicate)filterBlock {
    if (!filterBlock) {
        return self;
    }

    UAActionLiftBlock actionLiftBlock = ^(UAActionBlock actionBlock) {
        return actionBlock;
    };

    UAActionPredicateLiftBlock predicateLiftBlock = ^(UAActionPredicate predicate) {
        UAActionPredicate transformedPredicate = ^(UAActionArguments *args) {
            if (!filterBlock(args)) {
                return NO;
            }
            return predicate(args);
        };

        return transformedPredicate;
    };

    return [self lift:actionLiftBlock transformingPredicate:predicateLiftBlock];
}

- (UAAction *)map:(UAActionMapArgumentsBlock)mapArgumentsBlock {
    if (!mapArgumentsBlock) {
        return self;
    }

    UAActionLiftBlock actionLiftBlock = ^(UAActionBlock actionBlock) {
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, NSString *actionName, UAActionCompletionHandler handler) {
            actionBlock(mapArgumentsBlock(args), actionName, handler);
        };

        return transformedActionBlock;
    };

    UAActionPredicateLiftBlock predicateLiftBlock = ^(UAActionPredicate predicate) {
        UAActionPredicate transformedPredicate = ^(UAActionArguments *args) {
            return predicate(mapArgumentsBlock(args));
        };

        return transformedPredicate;
    };

    return [self lift:actionLiftBlock transformingPredicate:predicateLiftBlock];
}

- (UAAction *)preExecution:(UAActionPreExecutionBlock)preExecutionBlock {
    if (!preExecutionBlock) {
        return self;
    }

    UAActionLiftBlock liftBlock = ^(UAActionBlock actionBlock) {
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, NSString *actionName, UAActionCompletionHandler handler) {
            preExecutionBlock(args);
            actionBlock(args, actionName, handler);
        };
        return transformedActionBlock;
    };

    return [self lift:liftBlock];
}

- (UAAction *)postExecution:(UAActionPostExecutionBlock)postExecutionBlock {
    if (!postExecutionBlock) {
        return self;
    }

    UAActionLiftBlock liftBlock = ^(UAActionBlock actionBlock) {
        UAActionBlock transformedActionBlock = ^(UAActionArguments *args, NSString *actionName, UAActionCompletionHandler handler) {
            actionBlock(args, actionName, ^(UAActionResult *result) {
                postExecutionBlock(args, result);
                handler(result);
            });
        };
        return transformedActionBlock;
    };

    return [self lift:liftBlock];
}

@end
