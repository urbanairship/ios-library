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

NSString * const UASituationLaunchedFromPush = @"com.urbanairship.situation.launched_from_push";
NSString * const UASituationForegroundPush = @"com.urbanairship.situation.foreground_push";
NSString * const UASituationBackgroundPush = @"com.urbanairship.situation.background_push";
NSString * const UASituationRichPush = @"com.urbanairship.situation.rich_push";

@interface UAAction()
@property(nonatomic, copy) UAActionBlock actionBlock;
@end

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

- (void)performWithArguments:(UAActionArguments *)arguments withCompletionHandler:(UAActionCompletionHandler)completionHandler {
    if (self.actionBlock) {
        self.actionBlock(arguments, completionHandler);
    }
}

@end
