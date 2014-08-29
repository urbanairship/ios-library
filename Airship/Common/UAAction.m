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

#import "UAAction.h"
#import "UAAction+Internal.h"
#import "UAActionResult+Internal.h"
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

- (void)runWithArguments:(UAActionArguments *)arguments
              actionName:(NSString *)name
       completionHandler:(UAActionCompletionHandler)completionHandler {
    
    completionHandler = completionHandler ?: ^(UAActionResult *result) {
        //if no completion handler was passed, use an empty block in its place
    };
    
    typedef void (^voidBlock)(void);
    
    //execute the passed block directly if we're on the main thread, otherwise
    //dispatch it to the main queue
    void (^dispatchMainIfNecessary)(voidBlock) = ^(voidBlock block) {
        if (![[NSThread currentThread] isEqual:[NSThread mainThread]]) {
            dispatch_async(dispatch_get_main_queue(), block);
        } else {
            block();
        }
    };
    
    //make sure the initial acceptsArguments/willPerform/perform is executed on the main queue
    dispatchMainIfNecessary(^{
        if (![self acceptsArguments:arguments]) {
            UA_LDEBUG(@"Action %@ does not accept arguments %@.",
                     [self description], [arguments description]);
            completionHandler([UAActionResult rejectedArgumentsResult]);
        } else {
            [self willPerformWithArguments:arguments];
            [self performWithArguments:arguments
                            actionName:name
                     completionHandler:^(UAActionResult *result) {
                //make sure the passed completion handler and didPerformWithArguments are executed on the
                //main queue
                dispatchMainIfNecessary(^{
                    if (!result) {
                        UA_LWARN("Action %@ called the completion handler with a nil result", [self description]);
                    }
                    [self didPerformWithArguments:arguments withResult:result];
                    completionHandler(result);
                });
            }];
        }
    });
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

- (void)performWithArguments:(UAActionArguments *)args
                  actionName:(NSString *)name
           completionHandler:(UAActionCompletionHandler)completionHandler {
    if (self.actionBlock) {
        self.actionBlock(args, name, completionHandler);
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (void)didPerformWithArguments:(UAActionArguments *)arguments
                     withResult:(UAActionResult *)result {
    //override
}

#pragma mark factory methods

+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock {
    return [[self alloc] initWithBlock:actionBlock];
}

+ (instancetype)actionWithBlock:(UAActionBlock)actionBlock
             acceptingArguments:(UAActionPredicate)predicateBlock {
    UAAction *action = [self actionWithBlock:actionBlock];
    action.acceptsArgumentsBlock = predicateBlock;
    return action;
}

@end
