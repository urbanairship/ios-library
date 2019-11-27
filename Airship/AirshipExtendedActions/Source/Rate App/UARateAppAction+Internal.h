/* Copyright Airship and Contributors */

#import "UARateAppAction.h"

#if __has_include(<AirshipCore/AirshipCore.h>)
#import <AirshipCore/AirshipCore.h>
#else
#import "UASystemVersion.h"
#endif

@interface UARateAppAction()

/*
 * System version exposed for testing purposes
 */
@property (nonatomic, strong) UASystemVersion *systemVersion;

@end
