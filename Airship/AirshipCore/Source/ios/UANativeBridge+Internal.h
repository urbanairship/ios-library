/* Copyright Airship and Contributors */

#import "UANativeBridge.h"
#import "UANativeBridgeActionHandler+Internal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UANativeBridge()

+ (instancetype)nativeBridgeWithActionHandler:(UANativeBridgeActionHandler *)actionHandler
            javaScriptEnvironmentFactoryBlock:(UAJavaScriptEnvironment *(^)(void))javaScriptEnvironmentFactoryBlock;

@end

NS_ASSUME_NONNULL_END
