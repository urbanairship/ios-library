/* Copyright Airship and Contributors */

#import "UAChannelCaptureAction.h"
#import "UAChannelCapture.h"
#import "UAirship.h"


@implementation UAChannelCaptureAction

NSString * const UAChannelCaptureActionDefaultRegistryName = @"channel_capture_action";
NSString * const UAChannelCaptureActionDefaultRegistryAlias = @"^cc";

// Deprecated - to be removed in SDK version 14.0.
NSString * const kUAChannelCaptureActionDefaultRegistryName = UAChannelCaptureActionDefaultRegistryName;
NSString * const kUAChannelCaptureActionDefaultRegistryAlias = UAChannelCaptureActionDefaultRegistryAlias;

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationBackgroundPush:
            return [arguments.value isKindOfClass:[NSNumber class]];
        case UASituationAutomation:
        case UASituationWebViewInvocation:
        case UASituationLaunchedFromPush:
        case UASituationBackgroundInteractiveButton:
        case UASituationForegroundInteractiveButton:
        case UASituationForegroundPush:
            return NO;
    }
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {
    NSTimeInterval duration = [arguments.value doubleValue];
    if (duration > 0) {
        [[UAirship shared].channelCapture enable:duration];
    } else {
        [[UAirship shared].channelCapture disable];
    }
    
    completionHandler([UAActionResult emptyResult]);
}

@end
