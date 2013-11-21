/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

@class UAAppDelegateProxy;

@interface UAirship()

// Setters for public readonly-getters
@property (nonatomic, strong) UAAppDelegateProxy *appDelegate;
@property (nonatomic, strong) UALocationService *locationService;
@property (nonatomic, assign) BOOL ready;
@property (nonatomic, strong) UAConfig *config;
@property (nonatomic, strong) UAAnalytics *analytics;
@property (nonatomic, assign) BOOL backgroundNotificationEnabled;



/**
 * Should set this user agent up
 * User agent string should be:
 * App 1.0 (iPad; iPhone OS <version>; UALib <version>; <app key>; en_US)
 */
- (void)configureUserAgent;

/**
 * Handle app init. This should be called from NSNotification center
 * and will record a launch from notification and record the app init even
 * for analytics.
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

@end
