/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.
 
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

#import "UAUser.h"

// Current dictionary keys
#define kUserUrlKey @"UAUserUrlKey"

@class UAUserAPIClient;
@class UAConfig;
@class UAPreferenceDataStore;
@class UAPush;

NS_ASSUME_NONNULL_BEGIN

@interface UAUser()

/**
 * Factory method to create a user instance.
 * @param push The push manager.
 * @param config The Urban Airship config.
 * @param dataStore The preference data store.
 * @return UAUser instance.
 */
+ (instancetype)userWithPush:(UAPush *)push config:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;


/**
 * Updates the user's device token and or channel ID
 */
- (void)updateUser;

/**
 * Creates a user
 */
- (void)createUser;


/**
 * The user api client
 */
@property (nonatomic, strong) UAUserAPIClient *apiClient;

/**
 * The user name.
 */
@property (nonatomic, copy, nullable) NSString *username;

/**
 * The user's password.
 */
@property (nonatomic, copy, nullable) NSString *password;

/**
 * The user's url.
 */
@property (nonatomic, copy, nullable) NSString *url;


/**
 * Flag indicating if the  user is being created
 */
@property (nonatomic, assign) BOOL creatingUser;

/**
 * The preference data store
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * The Urban Airship config
 */
@property (nonatomic, strong) UAConfig *config;

@end

NS_ASSUME_NONNULL_END

