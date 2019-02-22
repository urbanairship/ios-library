/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAModules+Internal.h"

@interface UAComponentDisabler : NSObject

/**
 * UAComponentDisabler class factory method
 *
 * @param modules An instance of UAModules.
 */
+ (instancetype)componentDisablerWithModules:(UAModules *)modules;

/**
 * Processes an array of disable infos from remote config.
 * @param disableInfos an array of disable infos.
 */
- (void)processDisableInfo:(NSArray *)disableInfos;

@end
