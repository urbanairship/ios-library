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

#import "UABaseAppDelegateSurrogate.h"
#import "UAirship.h"
#import "UAPush.h"

@implementation UABaseAppDelegateSurrogate

- (id)init {
    //NSProxy has no default init method, so [super init] is unnecessary
    return self;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    SEL selector = [invocation selector];

    // Throw the exception here to make debugging easier. We are going to forward the invocation to the
    // defaultAppDelegate without checking if it responds for the purpose of crashing the app in the right place
    // if the delegate does not respond which would be expected behavior. If the defaultAppDelegate is nil, we
    // need to exception here, and not fail silently.
    if (!self.defaultAppDelegate) {
        NSString *errorMsg = @"UABaseAppDelegateSurrogate defaultAppDelegate was nil while forwarding an invocation";
        NSException *defaultAppDelegateNil = [NSException exceptionWithName:@"UAMissingDefaultDelegate"
                                                                     reason:errorMsg
                                                                   userInfo:nil];
        [defaultAppDelegateNil raise];
    }

    BOOL responds = NO;

    /*
     Give the surrogate and default app delegates an opportunity to handle the message

     NOTE: The order here is crucial. NSInvocation sets a return value after being invoked,
     which is the value returned to the original sender. Since our surrogateDelegate does not
     implement any methods with return values, we want to make sure that the defaultAppDelegate
     always wins, which means it should be invoked last.
     */
    if ([self.surrogateDelegate respondsToSelector:selector]) {
        responds = YES;
        [invocation invokeWithTarget:self.surrogateDelegate];
    }

    if ([self.defaultAppDelegate respondsToSelector:selector]) {
        responds = YES;
        [invocation invokeWithTarget:self.defaultAppDelegate];
    }

    if (!responds) {
        //In the off chance that neither app delegate responds, forward the message
        //to the default app delegate anyway.  this will likely result in a crash,
        //but that way the exception will come from the expected location
        [invocation invokeWithTarget:self.defaultAppDelegate];
    }
}


- (BOOL)respondsToSelector:(SEL)selector {
    // We only want to respond to the new notification delegate if background push is
    // enabled or the default app delegate responds to it.
    if ([NSStringFromSelector(selector) isEqualToString:@"application:didReceiveRemoteNotification:fetchCompletionHandler:"]) {
        return [UAirship shared].backgroundNotificationEnabled || [self.defaultAppDelegate respondsToSelector:selector];
    }

    //If this isn't a selector we normally respond to, say we do as long as either delegate does
    return ([self.defaultAppDelegate respondsToSelector:selector] || [self.surrogateDelegate respondsToSelector:selector]);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = nil;

    // First non nil method signature returns
    signature = [self.surrogateDelegate methodSignatureForSelector:selector];
    if (signature) return signature;

    signature = [self.defaultAppDelegate methodSignatureForSelector:selector];
    if (signature) return signature;

    // If none of the above classes return a non nil method signature, this will likely crash
    return signature;
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler {
    SEL selector = @selector(application:didReceiveRemoteNotification:fetchCompletionHandler:);

    __block int resultCount = 0;
    __block int expectedCount = 0;
    __block UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

    NSMutableArray *delegates = [NSMutableArray array];
    if ([self.surrogateDelegate respondsToSelector:selector]) {
        [delegates addObject:self.surrogateDelegate];
    }
    if ([self.defaultAppDelegate respondsToSelector:selector]) {
        [delegates addObject:self.defaultAppDelegate];
    }

    // if we have no delegates that respond to the selector, return early
    if (!delegates.count) {
        handler(fetchResult);
        return;
    }

    expectedCount = delegates.count;
    for (NSObject<UIApplicationDelegate> *delegate in delegates) {
        __block BOOL completionHandlerCalled = NO;
        [delegate application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:^(UIBackgroundFetchResult result) {
            @synchronized(self) {
                if (completionHandlerCalled) {
                    UA_LERR(@"Completion handler called multiple times.");
                    return;
                }

                completionHandlerCalled = YES;
                resultCount ++;

                // Merge the UIBackgroundFetchResults.  If final fetchResult is not already UIBackgroundFetchResultNewData
                // and the current result is not UIBackgroundFetchResultNoData, then set the fetchResult to result
                // (should be either UIBackgroundFetchFailed or UIBackgroundFetchResultNewData)
                if (fetchResult != UIBackgroundFetchResultNewData && result != UIBackgroundFetchResultNoData) {
                    fetchResult = result;
                }

                if (expectedCount == resultCount) {
                    handler(fetchResult);
                }
            }
        }];
    }
    
}

@end
