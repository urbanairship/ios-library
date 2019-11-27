/* Copyright Airship and Contributors */

#import "UARateAppAction.h"

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UASystemVersion.h"
#endif

@interface UARateAppAction()

/*
 * System version exposed for testing purposes
 */
@property (nonatomic, strong) UASystemVersion *systemVersion;

@end
