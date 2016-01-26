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

#import "UAAppDelegateProxy+Internal.h"

#import <objc/runtime.h>

#import "UAirship+Internal.h"
#import "UAPush.h"

static NSMutableDictionary *originalMethods_;

@implementation UAAppDelegateProxy

+ (void)proxyAppDelegate {
    if (!originalMethods_) {
        originalMethods_ = [NSMutableDictionary dictionary];
    }

    id delegate = [UIApplication sharedApplication].delegate;
    if (!delegate) {
        UA_LERR(@"App delegate not set, unable to perform automatic setup.");
        return;
    }

    Class class = [delegate class];

    // Check to make sure we do not already have entries for the class
    if (originalMethods_[NSStringFromClass(class)]) {
        UA_LDEBUG(@"Class %@ already swizzled.", NSStringFromClass(class));
        return;
    }

    // application:handleActionWithIdentifier:forRemoteNotification:completionHandler:
    [UAAppDelegateProxy swizzle:@selector(application:handleActionWithIdentifier:forRemoteNotification:completionHandler:)
                            implementation:(IMP)UAApplicationHandleActionWithIdentifierForRemoteNotificationCompletionHandler
                                     class:class];

    SEL responseInfoSelector = NSSelectorFromString(@"application:handleActionWithIdentifier:forRemoteNotification:withResponseInfo:completionHandler:");

    [UAAppDelegateProxy swizzle:responseInfoSelector implementation:(IMP)UAApplicationHandleActionWithIdentifierForRemoteNotificationWithResponseInfoCompletionHandler class:class];

    // application:didReceiveRemoteNotification:fetchCompletionHandler:
    // Needs to be above setting application:didReceiveRemoteNotification: because we
    // need to check if the delegate implments that selector before we add an implmeentation
    // for it
    if ([delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)] ||
        ![delegate respondsToSelector:@selector(application:didReceiveRemoteNotification:)] ||
        [UAirship shared].remoteNotificationBackgroundModeEnabled) {

        [UAAppDelegateProxy swizzle:@selector(application:didReceiveRemoteNotification:fetchCompletionHandler:)
                                implementation:(IMP)UAApplicationDidReceiveRemoteNotificationFetchCompletionHandler
                                         class:class];
    }

    // application:didReceiveRemoteNotification:
    [UAAppDelegateProxy swizzle:@selector(application:didReceiveRemoteNotification:)
                 implementation:(IMP)UAApplicationDidReceiveRemoteNotification class:class];

    // application:didRegisterForRemoteNotificationsWithDeviceToken
    [UAAppDelegateProxy swizzle:@selector(application:didRegisterForRemoteNotificationsWithDeviceToken:)
                 implementation:(IMP)UAApplicationDidRegisterForRemoteNotificationsWithDeviceToken class:class];

    // application:didRegisterUserNotificationSettings:
    [UAAppDelegateProxy swizzle:@selector(application:didRegisterUserNotificationSettings:)
                 implementation:(IMP)UAApplicationDidRegisterUserNotificationSettings
                          class:class];

    // application:didFailToRegisterForRemoteNotificationsWithError:
    [UAAppDelegateProxy swizzle:@selector(application:didFailToRegisterForRemoteNotificationsWithError:)
                 implementation:(IMP)UAApplicationDidFailToRegisterForRemoteNotificationsWithError
                          class:class];
}


+ (void)swizzle:(SEL)selector implementation:(IMP)implementation class:(Class)class {
    Method method = class_getInstanceMethod(class, selector);
    if (method) {
        UA_LDEBUG(@"Swizzling implementation for %@ class %@", NSStringFromSelector(selector), class);
        IMP existing = method_setImplementation(method, implementation);
        [UAAppDelegateProxy storeOriginalImplementation:existing selector:selector class:class];
    } else {
        struct objc_method_description description = protocol_getMethodDescription(@protocol(UIApplicationDelegate), selector, NO, YES);
        UA_LDEBUG(@"Adding implementation for %@ class %@", NSStringFromSelector(selector), class);
        class_addMethod(class, selector, implementation, description.types);
    }
}

+ (IMP)originalImplementation:(SEL)selector class:(Class)class {
    NSString *selectorString = NSStringFromSelector(selector);
    NSString *classString = NSStringFromClass(class);

    if (!originalMethods_[classString]) {
        return nil;
    }

    NSValue *value = originalMethods_[classString][selectorString];
    if (!value) {
        return nil;
    }

    IMP implementation;
    [value getValue:&implementation];
    return implementation;
}


+ (void)storeOriginalImplementation:(IMP)implementation selector:(SEL)selector class:(Class)class {
    NSString *selectorString = NSStringFromSelector(selector);
    NSString *classString = NSStringFromClass(class);

    if (!originalMethods_[classString]) {
        originalMethods_[classString] = [NSMutableDictionary dictionary];
    }

    originalMethods_[classString][selectorString] = [NSValue valueWithPointer:implementation];

}

void UAApplicationDidReceiveRemoteNotification(id self, SEL _cmd, UIApplication *application, NSDictionary *userInfo) {
    [[UAirship push] appReceivedRemoteNotification:userInfo applicationState:application.applicationState];

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, NSDictionary*))original)(self, _cmd, application, userInfo);
    }
}

void UAApplicationDidRegisterForRemoteNotificationsWithDeviceToken(id self, SEL _cmd, UIApplication *application, NSData *deviceToken) {
    [[UAirship push] appRegisteredForRemoteNotificationsWithDeviceToken:deviceToken];

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, NSData*))original)(self, _cmd, application, deviceToken);
    }
}

void UAApplicationDidRegisterUserNotificationSettings(id self, SEL _cmd, UIApplication *application, UIUserNotificationSettings *settings) {
    [[UAirship push] appRegisteredUserNotificationSettings];

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, UIUserNotificationSettings*))original)(self, _cmd, application, settings);
    }
}

void UAApplicationDidFailToRegisterForRemoteNotificationsWithError(id self, SEL _cmd, UIApplication *application, NSError *error) {
    UA_LERR(@"Application failed to register for remote notifications with error: %@", error);

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        ((void(*)(id, SEL, UIApplication *, NSError*))original)(self, _cmd, application, error);
    }
}

void UAApplicationDidReceiveRemoteNotificationFetchCompletionHandler(id self,
                                                                     SEL _cmd,
                                                                     UIApplication *application,
                                                                     NSDictionary *userInfo,
                                                                     void (^handler)(UIBackgroundFetchResult)) {

    __block NSUInteger resultCount = 0;
    __block NSUInteger expectedCount = 1;
    __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        expectedCount = 2;
        __block BOOL completionHandlerCalled = NO;

        void (^completionHandler)(UIBackgroundFetchResult) = ^(UIBackgroundFetchResult result) {

            // Make sure the app's completion handler is called on the main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandlerCalled) {
                    UA_LERR(@"Completion handler called multiple times.");
                    return;
                }

                completionHandlerCalled = YES;
                resultCount++;

                // Merge the UIBackgroundFetchResults. If final fetchResult is not already UIBackgroundFetchResultNewData
                // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
                // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
                if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
                    fetchResult = result;
                }

                if (expectedCount == resultCount) {
                    handler(fetchResult);
                }
            });
        };

        // Call the original implementation
        ((void(*)(id, SEL, UIApplication *, NSDictionary *, void (^)(UIBackgroundFetchResult)))original)(self, _cmd, application, userInfo, completionHandler);
    }

    // Our completion handler is called by the action framework on the main queue
    [[UAirship push] appReceivedRemoteNotification:userInfo
                                  applicationState:application.applicationState
                            fetchCompletionHandler:^(UIBackgroundFetchResult result) {
                                resultCount++;

                                // Merge the UIBackgroundFetchResults. If final fetchResult is not already UIBackgroundFetchResultNewData
                                // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
                                // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
                                if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
                                    fetchResult = result;
                                }

                                if (expectedCount == resultCount) {
                                    handler(fetchResult);
                                }
                            }];
}


void UAApplicationHandleActionWithIdentifierForRemoteNotificationCompletionHandler(id self,
                                                                                   SEL _cmd,
                                                                                   UIApplication *application,
                                                                                   NSString *identifier,
                                                                                   NSDictionary *userInfo,
                                                                                   void (^handler)()) {
    __block NSUInteger resultCount = 0;
    __block NSUInteger expectedCount = 1;

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        expectedCount = 2;

        __block BOOL completionHandlerCalled = NO;
        void (^completionHandler)() = ^() {

            // Make sure the app's completion handler is called on the main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandlerCalled) {
                    UA_LERR(@"Completion handler called multiple times.");
                    return;
                }

                completionHandlerCalled = YES;
                resultCount++;

                if (expectedCount == resultCount) {
                    handler();
                }
            });

        };

        // Call the original implementation
        ((void(*)(id, SEL, UIApplication *, NSString *, NSDictionary *, void (^)()))original)(self, _cmd, application, identifier, userInfo, completionHandler);
    }

    // Our completion handler is called by the action framework on the main queue
    [[UAirship push] appReceivedActionWithIdentifier:identifier
                                        notification:userInfo
                                    applicationState:application.applicationState
                                   completionHandler:^{
                                       resultCount++;

                                       if (expectedCount == resultCount) {
                                           handler();
                                       }
                                   }];
}

void UAApplicationHandleActionWithIdentifierForRemoteNotificationWithResponseInfoCompletionHandler(id self,
                                                                                   SEL _cmd,
                                                                                   UIApplication *application,
                                                                                   NSString *identifier,
                                                                                   NSDictionary *userInfo,
                                                                                   NSDictionary *responseInfo,
                                                                                   void (^handler)()) {
    __block NSUInteger resultCount = 0;
    __block NSUInteger expectedCount = 1;

    IMP original = [UAAppDelegateProxy originalImplementation:_cmd class:[self class]];
    if (original) {
        expectedCount = 2;

        __block BOOL completionHandlerCalled = NO;
        void (^completionHandler)() = ^() {

            // Make sure the app's completion handler is called on the main queue
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionHandlerCalled) {
                    UA_LERR(@"Completion handler called multiple times.");
                    return;
                }

                completionHandlerCalled = YES;
                resultCount++;

                if (expectedCount == resultCount) {
                    handler();
                }
            });

        };

        // Call the original implementation
        ((void(*)(id, SEL, UIApplication *, NSString *, NSDictionary *, NSDictionary *, void (^)()))original)(self, _cmd, application, identifier, userInfo, responseInfo, completionHandler);
    }

    // Our completion handler is called by the action framework on the main queue
    [[UAirship push] appReceivedActionWithIdentifier:identifier
                                        notification:userInfo
                                        responseInfo:responseInfo
                                    applicationState:application.applicationState
                                   completionHandler:^{
                                       resultCount++;

                                       if (expectedCount == resultCount) {
                                           handler();
                                       }
                                   }];
}

@end
