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
#import "UAActionResult.h"
#import "UAGlobal.h"

@interface UAAction()
@property(nonatomic, copy) UAActionBlock actionBlock;
@end

@implementation UAAction

- (instancetype)initWithBlock:(UAActionBlock)actionBlock {
    self = [super init];
    if (self) {
        self.actionBlock = actionBlock;

        //set a default predicate
        self.predicateBlock = ^(id args){
            return YES;
        };
    }

    return self;
}

+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock {
    return [[UAAction alloc] initWithBlock:actionBlock];
}

- (instancetype)continueWith:(UAAction *)continuationAction {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(id args, UAActionCompletionHandler completionHandler){
        [self performWithArguments:args withCompletionHandler:^(UAActionResult *selfResult){
            [continuationAction performWithArguments:selfResult.value withCompletionHandler:^(UAActionResult *continuationResult){
                //I think we may want to reduce the result or at least give the option in a similar operator...
                completionHandler(continuationResult);
            }];
        }];
    }];

    //copy over the predicate block from the receiver, so that the
    //aggregate action has the same restrictions as the head
    aggregateAction.predicateBlock = self.predicateBlock;

    return aggregateAction;
}

- (instancetype)foldWith:(UAAction *)foldedAction withFoldBlock:(UAActionFoldResultsBlock)foldBlock {
    if (!foldBlock) {
        //perhaps provide a default implementation for common use cases?
        UA_LWARN(@"missing foldBlock, returning nil");
        return nil;
    }

    UAAction *aggregateAction = [UAAction actionWithBlock:^(id args, UAActionCompletionHandler completionHandler){
        [self performWithArguments:args withCompletionHandler:^(UAActionResult *selfResult){
            [foldedAction performWithArguments:args withCompletionHandler:^(UAActionResult *foldedResult){
                completionHandler(foldBlock(selfResult, foldedResult));
            }];
        }];
    }];

    return aggregateAction;
}

- (instancetype)filter:(UAActionPredicate)predicateBlock {
    UAAction *aggregateAction = [UAAction actionWithBlock:^(id args, UAActionCompletionHandler completionHandler){
        [self performWithArguments:args withCompletionHandler:completionHandler];
    }];

    aggregateAction.predicateBlock = predicateBlock;

    return aggregateAction;
}

- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    if (![self canPerformWithArguments:arguments]) {
         completionHandler([UAActionResult none]);
    }

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


@end
