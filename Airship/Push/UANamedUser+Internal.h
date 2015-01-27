/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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

#import "UANamedUser.h"

@class UANamedUserAPIClient;

@interface UANamedUser ()

/**
 * Named user identifier data store key.
 */
extern NSString *const UANamedUserIdKey;

/**
 * Named user change token data store key.
 */
extern NSString *const UANamedUserChangeTokenKey;

/**
 * Named user last updated token data store key.
 */
extern NSString *const UANamedUserLastUpdatedTokenKey;

/**
 * The change token tracks the start of setting the named user ID.
 */
@property (nonatomic, copy) NSString *changeToken;

/**
 * The last updated token tracks when the named user ID was set successfully.
 */
@property (nonatomic, copy) NSString *lastUpdatedToken;

/**
 * The named user API client.
 */
@property (nonatomic, strong) UANamedUserAPIClient *namedUserAPIClient;

/**
 * The data store to save and load named user info.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * Initializes the Named User with the specified data store.
 * @param dataStore The shared preference data store.
 */
- (instancetype)initWithDataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Update named user.
 */
- (void)update;

@end
