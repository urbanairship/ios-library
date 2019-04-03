/* Copyright Urban Airship and Contributors */

#import "UALandingPageAction.h"
#import "UAOverlayViewController.h"
#import "UAURLProtocol.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "NSString+UAURLEncoding.h"
#import "UAUtils+Internal.h"

@implementation UALandingPageAction

NSString *const UALandingPageURLKey = @"url";
NSString *const UALandingPageHeightKey = @"height";
NSString *const UALandingPageWidthKey = @"width";
NSString *const UALandingPageAspectLockKey = @"aspect_lock";
NSString *const UALandingPageFill = @"fill";

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

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSURL *landingPageURL = [self parseURLFromValue:arguments.value];
    CGSize landingPageSize = [self parseSizeFromValue:arguments.value];
    BOOL aspectLock = [self parseAspectLockOptionFromValue:arguments.value];

    // load the landing page
    [UAOverlayViewController showURL:landingPageURL withHeaders:headers size:landingPageSize aspectLock:aspectLock];
    completionHandler([UAActionResult resultWithValue:nil withFetchResult:UAActionFetchResultNewData]);
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

    return YES;
}

@end
