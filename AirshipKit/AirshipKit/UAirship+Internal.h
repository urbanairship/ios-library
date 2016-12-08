/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.
 
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

#import "UAirship.h"

@class UABaseAppDelegateSurrogate;
@class UAJavaScriptDelegate;
@class UAPreferenceDataStore;
@class UAChannelCapture;

@interface UAirship()

NS_ASSUME_NONNULL_BEGIN

// Setters for public readonly-getters
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAAnalytics *analytics;
@property (nonatomic, strong) UAActionRegistry *actionRegistry;
@property (nonatomic, assign) BOOL remoteNotificationBackgroundModeEnabled;
@property (nonatomic, strong, nullable) id<UAJavaScriptDelegate> actionJSDelegate;
@property (nonatomic, strong) UAApplicationMetrics *applicationMetrics;
@property (nonatomic, strong) UAWhitelist *whitelist;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UAChannelCapture *channelCapture;

/**
 * The push manager.
 */
@property (nonatomic, strong) UAPush *sharedPush;


/**
 * The inbox user.
 */
@property (nonatomic, strong) UAUser *sharedInboxUser;

/**
 * The inbox.
 */
@property (nonatomic, strong) UAInbox *sharedInbox;

/**
 * The in-app messaging manager.
 */
@property (nonatomic, strong) UAInAppMessaging *sharedInAppMessaging;

/**
 * The default message center.
 */
@property (nonatomic, strong) UADefaultMessageCenter *sharedDefaultMessageCenter;

/**
 * The location manager.
 */
@property (nonatomic, strong) UALocation *sharedLocation;

/**
 * The named user.
 */
@property (nonatomic, strong) UANamedUser *sharedNamedUser;


/**
 * Shared automation manager.
 */
@property (nonatomic, strong) UAAutomation *sharedAutomation;


/**
 * Handle app init. This should be called from NSNotification center
 * and will record a launch from notification and record the app init even
 * for analytics.
 * @param notification The app did finish launching notification
 */
+ (void)handleAppDidFinishLaunchingNotification:(NSNotification *)notification;

/**
 * Handle a termination event from NSNotification center (forward it to land)
 * @param notification The app termination notification
 */
+ (void)handleAppTerminationNotification:(NSNotification *)notification;

/**
 * Perform teardown on the shared instance. This will automatically be called when an application
 * terminates.
 */
+ (void)land;

NS_ASSUME_NONNULL_END

@end
