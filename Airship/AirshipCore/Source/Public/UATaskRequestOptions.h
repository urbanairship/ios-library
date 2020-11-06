/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Conflict policy if a task with the same ID is already scheduled.
 * @note For internal use only. :nodoc:
 */
typedef NS_ENUM(NSUInteger, UATaskConflictPolicy) {
    /**
     * Keep previously scheduled task.
     */
    UATaskConflictPolicyKeep,

    /**
     * Replace previously scheduled task with new request.
     */
    UATaskConflictPolicyReplace,

    /**
     * Add new task but leave previously scheduled tasks.
     */
    UATaskConflictPolicyAppend,
};

/**
 * Task request options.
 * @note For internal use only. :nodoc:
 */
@interface UATaskRequestOptions : NSObject

/**
 * `YES` if network is required, otherwise `NO`.
 */
@property(nonatomic, readonly) BOOL isNetworkRequired;

/**
 * Optional request extras.
 */
@property(nonatomic, readonly, nullable) NSDictionary *extras;

/**
 * Conflict policy.
 */
@property(nonatomic, readonly) UATaskConflictPolicy conflictPolicy;

/**
 * Default task request options. The default requires network and uses `UATaskConflictPolicyReplace`.
 * @return The default request options.
 */
+ (instancetype)defaultOptions;

/**
 * Creates new options.
 * @param conflictPolicy The conflict policy.
 * @param requiresNetwork If network is required.
 * @param extras Request extras.
 */
+ (instancetype)optionsWithConflictPolicy:(UATaskConflictPolicy)conflictPolicy
                          requiresNetwork:(BOOL)requiresNetwork
                                   extras:(nullable NSDictionary *)extras;

@end

NS_ASSUME_NONNULL_END
