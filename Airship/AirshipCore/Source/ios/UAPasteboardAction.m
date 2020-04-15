/* Copyright Airship and Contributors */

#import "UAPasteboardAction.h"
#import "UAActionArguments.h"

@implementation UAPasteboardAction

NSString * const UAPasteboardActionDefaultRegistryName = @"clipboard_action";
NSString * const UAPasteboardActionDefaultRegistryAlias = @"^c";

// Deprecated - to be removed in SDK version 14.0.
NSString * const kUAPasteboardActionDefaultRegistryName = UAPasteboardActionDefaultRegistryName;
NSString * const kUAPasteboardActionDefaultRegistryAlias = UAPasteboardActionDefaultRegistryAlias;

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
