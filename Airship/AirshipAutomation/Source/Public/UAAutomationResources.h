/* Copyright Airship and Contributors */


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Interface for accessing AirshipAutomation resources.
 */
NS_SWIFT_NAME(AutomationResources)
@interface UAAutomationResources : NSObject

/**
 * The resource bundle.
 * @return The resource bundle.
 */
+ (NSBundle *)bundle;

@end

NS_ASSUME_NONNULL_END
