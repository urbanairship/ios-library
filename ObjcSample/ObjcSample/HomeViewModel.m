/* Copyright Airship and Contributors */

#import "HomeViewModel.h"
#import <UIKit/UIKit.h>

@import AirshipObjectiveC;

@interface HomeViewModel ()
@property (nonatomic, copy) void (^updateHandler)(void);
@end

@implementation HomeViewModel

- (instancetype)init {
    self = [super init];
    if (self) {

        // Initialize from Airship
        self.channelID = UAirship.channel.identifier;
        self.pushEnabled = UAirship.push.userPushNotificationsEnabled;
    }
    return self;
}

- (void)startObserversWithUpdateHandler:(void (^)(void))updateHandler {
    self.updateHandler = updateHandler;
}

- (void)stopObservers {
    self.updateHandler = nil;
}

- (void)copyChannel {
    if (self.channelID) {
        [UIPasteboard generalPasteboard].string = self.channelID;
    }
}

- (void)channelUpdated {
    self.channelID = UAirship.channel.identifier;
    [self triggerUpdate];
}

- (void)pushStatusChanged {
    self.pushEnabled = UAirship.push.userPushNotificationsEnabled;
    [self triggerUpdate];
}

- (void)triggerUpdate {
    if (self.updateHandler) {
        self.updateHandler();
    }
}

- (void)togglePushEnabled {
    if (!self.pushEnabled) {
        // Enable push
        UAirship.push.userPushNotificationsEnabled = YES;
    } else {
        // Disable push
        UAirship.push.userPushNotificationsEnabled = NO;
    }
}

@end
