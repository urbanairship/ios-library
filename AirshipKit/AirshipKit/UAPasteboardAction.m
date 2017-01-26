/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import "UAPasteboardAction.h"
#import "UAActionArguments.h"

@implementation UAPasteboardAction

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationWebViewInvocation:
        case UASituationLaunchedFromPush:
        case UASituationBackgroundInteractiveButton:
        case UASituationForegroundInteractiveButton:
        case UASituationAutomation:
            return [self pasteboardStringWithArguments:arguments] != nil;
        case UASituationBackgroundPush:
        case UASituationForegroundPush:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    [UIPasteboard generalPasteboard].string = [self pasteboardStringWithArguments:arguments];
    
    completionHandler([UAActionResult resultWithValue:arguments.value]);
}

- (NSString *)pasteboardStringWithArguments:(UAActionArguments *)arguments {
    if ([arguments.value isKindOfClass:[NSString class]]) {
        return arguments.value;
    }

    if ([arguments.value isKindOfClass:[NSDictionary class]] && [arguments.value[@"text"] isKindOfClass:[NSString class]]) {
        return arguments.value[@"text"];
    }

    return nil;
}
@end
