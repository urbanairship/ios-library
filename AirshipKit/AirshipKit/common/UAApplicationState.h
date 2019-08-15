/* Copyright Airship and Contributors */

/**
 * Platform independent representation of application state.
 */
typedef NS_ENUM(NSUInteger, UAApplicationState) {
    /**
     * The active state.
     */
    UAApplicationStateActive,
    /**
     * The inactive state.
     */
    UAApplicationStateInactive,
    /**
     * The background state.
     */
    UAApplicationStateBackground
};

