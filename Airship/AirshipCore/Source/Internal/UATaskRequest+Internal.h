/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UATaskLauncher+Internal.h"
#import "UATaskRequestOptions.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * A task request instance.
 */
@interface UATaskRequest : NSObject

/**
 * Task ID.
 */
@property(nonatomic, readonly) NSString *taskID;

/**
 * The task request options.
 */
@property(nonatomic, readonly) UATaskRequestOptions *options;

/**
 * Task launcher.
 */
@property(nonatomic, readonly) UATaskLauncher *launcher;

/**
 * Factory method.
 * @param taskID The task ID.
 * @param options The task request options.
 * @param launcher The task launcher.
 */
+ (instancetype)requestWithID:(NSString *)taskID
                      options:(UATaskRequestOptions *)options
                     launcher:(UATaskLauncher *)launcher;
@end

NS_ASSUME_NONNULL_END
