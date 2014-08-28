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

@interface UAAction ()

/**
 * A block defining the primary work performed by an action.
 * In the base class, this block is executed by the default implementation of
 * [UAAction performWithArguments:withCompletionHandler:]
 */
@property (nonatomic, copy) UAActionBlock actionBlock;

/**
 * A block that indicates whether the action is willing to accept the provided arguments.
 * In the base class, this block is executed by the default implementation of
 * [UAAction acceptsArguments:]
 */
@property (nonatomic, copy) UAActionPredicate acceptsArgumentsBlock;

/**
 * Performs the action, with pre/post execution calls, if it accepts the provided arguments.
 *
 * If the arguments are accepted, this method will also call
 * [UAAction willPerformWithArguments:] and
 * [UAAction didPerformWithArguments:withResult:]
 * before and after the perform method, respectively.
 *
 * @param arguments The action's arguments.
 * @param name The action's name.
 * @param completionHandler CompletionHandler when the action is finished.
 */
- (void)runWithArguments:(UAActionArguments *)arguments
              actionName:(NSString *)name
       completionHandler:(UAActionCompletionHandler)completionHandler;


@end
