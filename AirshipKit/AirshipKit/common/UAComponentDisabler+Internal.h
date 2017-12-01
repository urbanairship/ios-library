/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@interface UAComponentDisabler : NSObject

/**
 * Processes an array of disable infos from remote config.
 * @param disableInfos an array of disable infos.
 */
- (void)processDisableInfo:(NSArray *)disableInfos;
@end
