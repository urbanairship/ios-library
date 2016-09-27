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

#import "UAInAppMessaging.h"
#import "UAInAppMessageController+Internal.h"

// User defaults key for storing and retrieving pending messages
#define kUAPendingInAppMessageDataStoreKey @"UAPendingInAppMessage"

// User defaults key for storing and retrieving auto display enabled
#define kUAAutoDisplayInAppMessageDataStoreKey @"UAAutoDisplayInAppMessageDataStoreKey"

@class UAPreferenceDataStore;
@class UAAnalytics;
@class UAPush;

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessaging ()

/**
 * A Boolean value indicating whether or not the keyboard is displayed.
 */
@property(nonatomic, assign, getter=isKeyboardDisplayed) BOOL keyboardDisplayed;

/**
 * Factory method to create an UAInAppMessaging instance.
 * @param analytics The UAAnalytics instance.
 * @param dataStore The preference data store.
 * @return An instance of UAInAppMessaging.
 */
+ (instancetype)inAppMessagingWithAnalytics:(UAAnalytics *)analytics
                                  dataStore:(UAPreferenceDataStore *)dataStore;

/**
 * Invalidates the autodisplay timer.
 */
- (void)invalidateAutoDisplayTimer;

@end

NS_ASSUME_NONNULL_END
