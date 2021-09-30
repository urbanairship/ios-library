/* Copyright Airship and Contributors */

#import "UALandingPageAction.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppAutomation+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageSchedule.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif
NSString * const UALandingPageActionDefaultRegistryName = @"landing_page_action";
NSString * const UALandingPageActionDefaultRegistryAlias = @"^p";

@implementation UALandingPageAction

NSString *const UALandingPageURLKey = @"url";
NSString *const UALandingPageHeightKey = @"height";
NSString *const UALandingPageWidthKey = @"width";
NSString *const UALandingPageAspectLockKey = @"aspect_lock";
NSString *const UALandingPageAspectLockLegacyKey = @"aspectLock";

CGFloat const UALandingPageDefaultBorderRadiusPoints = 2;

- (NSURL *)parseURLFromValue:(id)value {
    NSURL *url;

    if ([value isKindOfClass:[NSURL class]]) {
        url = value;
    }

    if ([value isKindOfClass:[NSString class]]) {
        url = [NSURL URLWithString:value];
    }

    if ([value isKindOfClass:[NSDictionary class]]) {
        id urlValue = [value valueForKey:UALandingPageURLKey];

        if (urlValue && [urlValue isKindOfClass:[NSString class]]) {
            url = [NSURL URLWithString:urlValue];
        }
    }

    if  (url && !url.scheme.length) {
        NSString *absoluteURLPath = [url absoluteString];
        if (!absoluteURLPath) {
            return nil;
        }
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:absoluteURLPath]];
    }

    return url;
}

- (CGSize)parseSizeFromValue:(id)value {

    if ([value isKindOfClass:[NSDictionary class]]) {
        CGFloat widthValue = 0;
        CGFloat heightValue = 0;

        if ([[value valueForKey:UALandingPageWidthKey] isKindOfClass:[NSNumber class]]) {
            widthValue = [[value valueForKey:UALandingPageWidthKey] floatValue];
        }

        if ([[value valueForKey:UALandingPageHeightKey] isKindOfClass:[NSNumber class]]) {
            heightValue = [[value valueForKey:UALandingPageHeightKey] floatValue];
        }

        return CGSizeMake(widthValue, heightValue);
    }

    return CGSizeZero;
}

- (BOOL)parseAspectLockOptionFromValue:(id)value {
    if ([value isKindOfClass:[NSDictionary class]]) {
        id aspectLockValue = [value valueForKey:UALandingPageAspectLockKey];

        if ([aspectLockValue isKindOfClass:[NSNumber class]]) {
            return [(NSNumber *)aspectLockValue boolValue];
        }

        id legacyAspectLockValue = [value valueForKey:UALandingPageAspectLockLegacyKey];

        if ([legacyAspectLockValue isKindOfClass:[NSNumber class]]) {
            // key "aspectLock" is still accepted by the API
            return [(NSNumber *)legacyAspectLockValue boolValue];
        }
    }

    return NO;
}

- (NSURL *)parseURLFromArguments:(UAActionArguments *)arguments {
    NSURL *landingPageURL = [self parseURLFromValue:arguments.value];

    return landingPageURL;
}

- (UASchedule *)createScheduleWithActionArguments:(UAActionArguments *)arguments {
    NSURL *landingPageURL = [self parseURLFromArguments:arguments];
    CGSize landingPageSize = [self parseSizeFromValue:arguments.value];

    BOOL aspectLock = [self parseAspectLockOptionFromValue:arguments.value];

    BOOL reportEvent = NO;
    NSDictionary *payload = arguments.metadata[UAActionMetadataPushPayloadKey];

    // Note this is the in-app message ID, not to be confused with the inbox message ID
    NSString *messageID = payload[@"_"];
    if (messageID != nil) {
        reportEvent = YES;
    } else {
        messageID = [NSUUID UUID].UUIDString;
    }

    id<UALandingPageBuilderExtender> extender = self.builderExtender;

    UAInAppMessage *message = [UAInAppMessage messageWithBuilderBlock:^(UAInAppMessageBuilder * _Nonnull builder) {
        UAInAppMessageHTMLDisplayContent *displayContent = [UAInAppMessageHTMLDisplayContent displayContentWithBuilderBlock:^(UAInAppMessageHTMLDisplayContentBuilder * _Nonnull builder) {
            builder.url = landingPageURL.absoluteString;
            builder.allowFullScreenDisplay = NO;
            builder.borderRadiusPoints = [self.borderRadiusPoints floatValue] ?: UALandingPageDefaultBorderRadiusPoints;
            builder.width = landingPageSize.width;
            builder.height = landingPageSize.height;
            builder.aspectLock = aspectLock;
            builder.requiresConnectivity = NO;
        }];

        builder.displayContent = displayContent;
        builder.isReportingEnabled = reportEvent;
        builder.displayBehavior = UAInAppMessageDisplayBehaviorImmediate;

        // Allow the app to customize the message builder if necessary
        if (extender && [extender respondsToSelector:@selector(extendMessageBuilder:)]) {
            [extender extendMessageBuilder:builder];
        }
    }];

    return [UAInAppMessageSchedule scheduleWithMessage:message builderBlock:^(UAScheduleBuilder * _Nonnull builder) {
        builder.identifier = messageID;
        builder.priority = 0;
        builder.limit = 1;
        builder.triggers = @[[UAScheduleTrigger triggerWithType:UAScheduleTriggerActiveSession goal:@(1) predicate:nil]];

        // Allow the app to customize the schedule builder if necessary
        if (extender && [extender respondsToSelector:@selector(extendScheduleBuilder:)]) {
            [extender extendScheduleBuilder:builder];
        }
    }];
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    UASchedule *schedule = [self createScheduleWithActionArguments:arguments];

    [[UAInAppAutomation shared] schedule:schedule completionHandler:^(BOOL result) {
        completionHandler([UAActionResult emptyResult]);
    }];
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    if (arguments.situation == UASituationBackgroundInteractiveButton || arguments.situation == UASituationBackgroundPush) {
        return NO;
    }

    NSURL *url = [self parseURLFromValue:arguments.value];
    if (!url) {
        return NO;
    }

    if (![[UAirship shared].URLAllowList isAllowed:url scope:UAURLAllowListScopeOpenURL]) {
        UA_LERR(@"URL %@ not allowed. Unable to display landing page.", url);
        return NO;
    }

    return YES;
}

@end
