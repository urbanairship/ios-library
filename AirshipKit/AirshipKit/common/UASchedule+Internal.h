/* Copyright Urban Airship and Contributors */

#import "UASchedule.h"

NS_ASSUME_NONNULL_BEGIN

/*
 * SDK-private extensions to UASchedule
 */
@interface UASchedule()

///---------------------------------------------------------------------------------------
/// @name Schedule Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The schedule's identifier.
 */
@property(nonatomic, copy) NSString *identifier;

/**
 * The schedule's information.
 */
@property(nonatomic, strong) UAScheduleInfo *info;

/**
 * The schedule's metadata.
 *
 * @note metadata includes the locale which can change at any time.
 */
@property(nonatomic, strong) NSDictionary *metadata;

///---------------------------------------------------------------------------------------
/// @name Schedule Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a schedule.
 * @param identifier The schedule's identifier.
 * @param info The schedule's info.
 * @param metadata The schedule's metadata.
 */
+ (instancetype)scheduleWithIdentifier:(NSString *)identifier
                                  info:(UAScheduleInfo *)info
                              metadata:(NSDictionary *)metadata;

@end

NS_ASSUME_NONNULL_END
