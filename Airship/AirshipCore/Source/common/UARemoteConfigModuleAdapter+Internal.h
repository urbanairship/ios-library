/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * An interface mapping modules to components.
 */
@interface UARemoteConfigModuleAdapter : NSObject

/**
 * Enables or disables components for a given module name.
 * @param enabled `YES` to enable, `NO` to disable.
 * @parm moduleName The name of the module.
 */
- (void)setComponentsEnabled:(BOOL)enabled forModuleName:(NSString *)moduleName;

/**
 * Applies config for a given module name.
 * @param config The config.
 * @parm moduleName The name of the module.
 */
- (void)applyConfig:(nullable id)config forModuleName:(NSString *)moduleName;

@end

NS_ASSUME_NONNULL_END
