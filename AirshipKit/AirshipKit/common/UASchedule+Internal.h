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

///---------------------------------------------------------------------------------------
/// @name Schedule Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a schedule.
 * @param identifier The schedule's identifier.
 * @param info The schedule's info.
 */
+ (instancetype)scheduleWithIdentifier:(NSString *)identifier info:(UAScheduleInfo *)info;

@end

NS_ASSUME_NONNULL_END
