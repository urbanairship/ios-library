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
#import "UAPushActionArguments.h"
#import "UAActionResult.h"
/**
 * A block that defines the work performed by an action.
 */
typedef void (^UAPushActionBlock)(UAPushActionArguments *, UAActionCompletionHandler);

@interface UAPushAction : UAAction

+ (instancetype)pushActionWithBlock:(UAPushActionBlock)actionBlock;

/**
 * Triggers the action. Subclasses of UAPushAction should override this method to define custom behavior.
 *
 * @param arguments A UAPushActionArguments value representing the arguments passed to the action.
 * @param completionHandler A UAActionCompletionHandler that signals the completion of the action.
 * @return An instance of UAActionResult.
 */
- (void)performWithPushArguments:(UAPushActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler;

@end
