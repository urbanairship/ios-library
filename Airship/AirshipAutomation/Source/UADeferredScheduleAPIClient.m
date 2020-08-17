/* Copyright Airship and Contributors */

#import "UADeferredScheduleAPIClient+Internal.h"

NSString * const UADeferredScheduleAPIClientErrorDomain = @"com.urbanairship.deferred_api_client";

@implementation UADeferredScheduleAPIClient

- (void)resolveURL:(NSURL *)URL
         channelID:(NSString *)channelID
    triggerContext:(nullable UAScheduleTriggerContext *)triggerContext
 completionHandler:(void (^)(UADeferredScheduleResult * _Nullable, NSError * _Nullable))completionHandler {

    NSError *error = [NSError errorWithDomain:UADeferredScheduleAPIClientErrorDomain
                                         code:UADeferredScheduleAPIClientErrorUnsuccessfulStatus
                                     userInfo:nil];
    completionHandler(nil, error);
}

@end
