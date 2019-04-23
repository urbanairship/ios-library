/* Copyright Urban Airship and Contributors */

#import "UALandingPageAction.h"
#import "UAURLProtocol.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "NSString+UAURLEncoding.h"
#import "UAUtils+Internal.h"
#import "UAInAppMessageScheduleInfo+Internal.h"
#import "UAInAppMessageHTMLDisplayContent+Internal.h"
#import "UAInAppMessageManager+Internal.h"
#import "UAOverlayInboxMessageAction+Internal.h"

@implementation UALandingPageAction

NSString *const UALandingPageURLKey = @"url";
NSString *const UALandingPageHeightKey = @"height";
NSString *const UALandingPageWidthKey = @"width";
NSString *const UALandingPageAspectLockKey = @"aspect_lock";

CGFloat const defaultBorderRadiusPoints = 2;

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
        url = [NSURL URLWithString:[@"https://" stringByAppendingString:[url absoluteString]]];
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
        if ([[value valueForKey:UALandingPageAspectLockKey] isKindOfClass:[NSNumber class]]) {
            // key "aspectLock" is still accepted by the API
            NSNumber *aspectLock = (NSNumber *)[value valueForKey:UALandingPageAspectLockKey];

            return aspectLock.boolValue;
        }
    }

    return NO;
}

- (NSURL *)parseURLFromArguments:(UAActionArguments *)arguments {
    NSURL *landingPageURL = [self parseURLFromValue:arguments.value];

    return landingPageURL;
}

- (UAInAppMessageScheduleInfo *)createScheduleInfoWithActionArguments:(UAActionArguments *)arguments {
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
            builder.borderRadiusPoints = [self.borderRadiusPoints floatValue] ?: defaultBorderRadiusPoints;
            builder.width = landingPageSize.width;
            builder.height = landingPageSize.height;
            builder.aspectLock = aspectLock;
            builder.requiresConnectivity = NO;
        }];

        builder.displayContent = displayContent;
        builder.identifier = messageID;
        builder.isReportingEnabled = reportEvent;
        builder.displayBehavior = UAInAppMessageDisplayBehaviorImmediate;

        // Allow the app to customize the message builder if necessary
        if (extender && [extender respondsToSelector:@selector(extendMessageBuilder:)]) {
            [extender extendMessageBuilder:builder];
        }
    }];

    UAInAppMessageScheduleInfo *scheduleInfo = [UAInAppMessageScheduleInfo scheduleInfoWithBuilderBlock:^(UAInAppMessageScheduleInfoBuilder * _Nonnull builder) {
        builder.message = message;
        builder.priority = 0;
        builder.limit = 1;
        builder.triggers = @[[UAScheduleTrigger triggerWithType:UAScheduleTriggerActiveSession goal:@(1) predicate:nil]];

        // Allow the app to customize the schedule info builder if necessary
        if (extender && [extender respondsToSelector:@selector(extendScheduleInfoBuilder:)]) {
            [extender extendScheduleInfoBuilder:builder];
        }
    }];

    return scheduleInfo;
}

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    UAInAppMessageScheduleInfo *scheduleInfo = [self createScheduleInfoWithActionArguments:arguments];

    [UAirship.inAppMessageManager scheduleMessageWithScheduleInfo:scheduleInfo
                                                completionHandler:^(UASchedule *schedule) {
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

    if (![[UAirship shared].whitelist isWhitelisted:url scope:UAWhitelistScopeOpenURL]) {
        UA_LERR(@"URL %@ not whitelisted. Unable to display landing page.", url);
        return NO;
    }

    if ([arguments.value isKindOfClass:[NSString class]] && [[arguments.value lowercaseString] isEqualToString:UAOverlayInboxMessageActionMessageIDPlaceHolder]) {
        return arguments.metadata[UAActionMetadataPushPayloadKey] ||
        arguments.metadata[UAActionMetadataInboxMessageKey];
    }

    return YES;
}

@end
