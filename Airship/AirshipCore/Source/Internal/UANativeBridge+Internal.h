/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#if !TARGET_OS_TV

#import "UANativeBridge.h"
#import "UANativeBridgeActionHandler+Internal.h"

NS_ASSUME_NONNULL_BEGIN

API_UNAVAILABLE(tvos)
@interface UANativeBridge()

+ (instancetype)nativeBridgeWithActionHandler:(UANativeBridgeActionHandler *)actionHandler
            javaScriptEnvironmentFactoryBlock:(UAJavaScriptEnvironment *(^)(void))javaScriptEnvironmentFactoryBlock;

@end

NS_ASSUME_NONNULL_END

#endif
