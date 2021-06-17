/* Copyright Airship and Contributors */

#import <StoreKit/StoreKit.h>
#import "UARateAppAction.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
@import AirshipCore;
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif

@implementation UARateAppAction

NSString * const UARateAppActionDefaultRegistryName = @"rate_app_action";
NSString * const UARateAppActionDefaultRegistryAlias = @"^ra";

// External
NSString *const UARateAppShowLinkPromptKey = @"show_link_prompt";
NSString *const UARateAppItunesIDKey = @"itunes_id";

// Internal
NSString *const UARateAppItunesURLFormat = @"itms-apps://itunes.apple.com/app/id%@?action=write-review";

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    BOOL showLinkPrompt = [[arguments.value numberForKey:UARateAppShowLinkPromptKey
                                            defaultValue:@(NO)] boolValue];

    NSString *itunesID = [arguments.value stringForKey:UARateAppItunesIDKey
                                          defaultValue:[UAirship shared].config.itunesID];

    if (showLinkPrompt) {
        [SKStoreReviewController requestReview];
        completionHandler([UAActionResult emptyResult]);
        return;
    } else if (itunesID.length) {
        NSString *linkString = [NSString stringWithFormat:UARateAppItunesURLFormat, itunesID];
        [self linkToStore:linkString];
        completionHandler([UAActionResult emptyResult]);
        return;
    } else {
        completionHandler([UAActionResult emptyResult]);
    }
}

- (BOOL)canLinkToStore:(NSString *)linkString {
    // If the URL can't be opened, bail before displaying
    if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:linkString]]) {
        UA_LWARN(@"Unable to open iTunes URL: %@", linkString);
        return NO;
    }
    return YES;
}

// Opens link to iTunes store rating section
-(void)linkToStore:(NSString *)linkString {
    if (![self canLinkToStore:linkString]) {
        return;
    }

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkString] options:@{} completionHandler:nil];
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationAutomation:
        case UASituationLaunchedFromPush:
        case UASituationForegroundInteractiveButton:
        case UASituationWebViewInvocation:
            if (arguments.value == nil || ![arguments.value isKindOfClass:[NSDictionary class]]) {
                UA_LERR(@"Unable to parse arguments: %@", arguments);
                return NO;
            }
            return YES;
        case UASituationForegroundPush:
        case UASituationBackgroundPush:
        case UASituationBackgroundInteractiveButton:
        default:
            return NO;
    }
}

@end
