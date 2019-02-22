/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAInAppMessageButtonInfo.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Resolution types.
 */
typedef NS_ENUM(NSInteger, UAInAppMessageResolutionType) {
    /**
     * Button click resolution.
     */
    UAInAppMessageResolutionTypeButtonClick = 0,

    /**
     * Message click resolution.
     */
    UAInAppMessageResolutionTypeMessageClick = 1,

    /**
     * User dismissed resolution.
     */
    UAInAppMessageResolutionTypeUserDismissed = 2,

    /**
     * Timed out resolution.
     */
    UAInAppMessageResolutionTypeTimedOut = 3
};

/**
 * In-app message resolution info.
 */
@interface UAInAppMessageResolution : NSObject

/**
 * Button info for a message click resolution.
 */
@property (nonatomic, readonly, nullable) UAInAppMessageButtonInfo *buttonInfo;


/**
 * Resolution type.
 */
@property (nonatomic, readonly) UAInAppMessageResolutionType type;

/**
 * Creates a button click resolution instance.
 *
 * @param buttonInfo The button info.
 * @return The resolution instance.
 */
+ (instancetype)buttonClickResolutionWithButtonInfo:(UAInAppMessageButtonInfo *)buttonInfo;

/**
 * Creates a message click resolution instance.
 *
 * @return The resolution instance.
 */
+ (instancetype)messageClickResolution;

/**
 * Creates a user dismissed resolution instance.
 *
 * @return The resolution instance.
 */
+ (instancetype)userDismissedResolution;

/**
 * Creates a timed out resolution instance.
 *
 * @return The resolution instance.
 */
+ (instancetype)timedOutResolution;



@end
NS_ASSUME_NONNULL_END
