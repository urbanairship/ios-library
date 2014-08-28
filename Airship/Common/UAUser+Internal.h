/*
 Copyright 2009-2014 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
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

#import "UAUser.h"

// Current dictionary keys
#define kUserUrlKey @"UAUserUrlKey"

@class UAHTTPRequest;
@class UAUserAPIClient;

@interface UAUser()

/**
 * Registers for device registration changes on UAPush
 */
- (void)registerForDeviceRegistrationChanges;

/**
 * Unregisters for device registration changes on UAPush
 */
- (void)unregisterForDeviceRegistrationChanges;

/**
 * Updates the user's device token and or channel id
 */
- (void)updateUser;

/**
 * Creates a user
 */
- (void)createUser;

/**
 * Invalidate the user update background task.
 */
- (void)invalidateUserUpdateBackgroundTask;

/**
 * The user api client
 */
@property (nonatomic, strong) UAUserAPIClient *apiClient;

/**
 * Flag indicating if the user has been initialized
 */
@property (nonatomic, assign) BOOL initialized;

/**
 * The user name.
 */
@property (nonatomic, copy) NSString *username;

/**
 * The user's password.
 */
@property (nonatomic, copy) NSString *password;

/**
 * The user's url.
 */
@property (nonatomic, copy) NSString *url;

/**
 * Background task identifier used to perform user updates in the background.
 */
@property (nonatomic, assign) UIBackgroundTaskIdentifier userUpdateBackgroundTask;

/**
 * Flag indicating if the device registration changes are being observed or not
 */
@property (nonatomic, assign) BOOL isObservingDeviceRegistrationChanges;

/**
 * The current app key
 */
@property (nonatomic, readonly) NSString *appKey;

/**
 * Flag indicating if the  user is being created
 */
@property (nonatomic, assign) BOOL creatingUser;

@end

