/* Copyright Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * An enum representing a subtype of tag groups.
 */
typedef NS_ENUM(NSUInteger, UATagGroupsType) {
    /**
     * Represents channel tag groups.
     */
    UATagGroupsTypeChannel = 0,
    /**
     * Represents named user tag groups.
     */
    UATagGroupsTypeNamedUser = 1,
};
