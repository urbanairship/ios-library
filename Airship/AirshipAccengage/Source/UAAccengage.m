/* Copyright Airship and Contributors */

#import "UAAccengage+Internal.h"

@implementation UAAccengage

- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore
                          channel:(UAChannel *)channel
                             push:(UAPush *)push
                        analytics:(UAAnalytics *)analytics {
    self = [super initWithDataStore:dataStore];
    if (self) {

    }
    return self;
}

+ (instancetype)accengageWithDataStore:(UAPreferenceDataStore *)dataStore
                               channel:(UAChannel *)channel
                                  push:(UAPush *)push
                             analytics:(UAAnalytics *)analytics {

    return [[self alloc] init];
}

-(void)receivedNotificationResponse:(UANotificationResponse *)response
                  completionHandler:(void (^)(void))completionHandler {
    // check for accengage push response, handle actions
    completionHandler();
}

@end
