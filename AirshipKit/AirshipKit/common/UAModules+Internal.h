/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent+Internal.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The push module.
 */
extern NSString * const UAModulesPush;

/**
 * The analytics module.
 */
extern NSString * const UAModulesAnalytics;

/**
 * The message center module.
 */
extern NSString * const UAModulesMessageCenter;

/**
 * The in-app messaging module.
 */
extern NSString * const UAModulesInAppMessaging;

/**
 * The automation module.
 */
extern NSString * const UAModulesAutomation;

/**
 * The named user module.
 */
extern NSString * const UAModulesNamedUser;

/**
 * The location module.
 */
extern NSString * const UAModulesLocation;

/**
 * An interface mapping modules to components, and providing hooks for common operations.
 */
@interface UAModules : NSObject

/**
 * Produces all the modules currently known to the system.
 *
 * @return An array of module names.
 */
- (NSArray<NSString *> *)allModuleNames;

/**
 * Retrieves the component associated with the provided module name, or nil if one could not be found.
 *
 * @param moduleName The module name.
 * @return The corresponding component, or nil if one was not found.
 */
- (nullable UAComponent *)airshipComponentForModuleName:(NSString *)moduleName;

/**
 * Processes configs for all modules.
 *
 * @param configs A dictionary mapping module names to remote config JSON dictionaries.
 */
- (void)processConfigs:(NSDictionary *)configs;

@end

NS_ASSUME_NONNULL_END
