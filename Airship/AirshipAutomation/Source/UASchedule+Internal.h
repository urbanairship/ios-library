/* Copyright Airship and Contributors */

#import "UASchedule.h"
#import "UAScheduleDeferredData.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UAScheduleType) {

    /**
     * In-app message type.
     */
    UAScheduleTypeInAppMessage,

    /**
     * Actions type.
     */
    UAScheduleTypeActions,

    /**
     * Deferred type.
     */
    UAScheduleTypeDeferred
};

/**
 * UASchedule extension.
 */
@interface UASchedule()

/**
 * The schedule type.
 */
@property(nonatomic, readonly) UAScheduleType type;

/**
 * Schedule data.
 */
@property(nonatomic, readonly) id data;

/**
 * Campaigns info.
 */
@property(nonatomic, readonly) NSDictionary *campaigns;

/**
 * Reporting context
 */
@property(nonatomic, readonly) NSDictionary *reportingContext;

@property(nonatomic, readonly) NSString *dataJSONString;

/**
 * Audience JSON
 */
@property(nonatomic, readonly) NSDictionary *audienceJSON;

/**
 * Audience miss behavior
 */
@property(nonatomic, readonly) UAScheduleAudienceMissBehaviorType audienceMissBehavior;

/**
 * New user evaluation date.
 */
@property(nonatomic, readonly, nullable) NSDate *isNewUserEvaluationDate;

/**
 * The schedule's message type.
 *
 * optional.
 */
@property(nonatomic, readonly, nullable) NSString *messageType;

/**
 * Indicates if schedule could be in holdout group
 */
@property(nonatomic, assign) BOOL bypassHoldoutGroups;

/**
 * Frequency constraint IDs.
 */
@property(nonatomic, readonly) NSArray<NSString *> *frequencyConstraintIDs;


- (instancetype)initWithData:(id)data
                        type:(UAScheduleType)scheduleType
                     builder:(UAScheduleBuilder *)builder;

@end

/**
 * UAScheduleBuilder extension
 */
@interface UAScheduleBuilder ()

/**
 * Campaigns info.
 */
@property(nonatomic, copy, nullable) NSDictionary *campaigns;

/**
 * Reporing context.
 */
@property(nonatomic, copy, nullable) NSDictionary *reportingContext;

/**
 * Frequency constraint IDs.
 */
@property (nonatomic, copy, nullable) NSArray<NSString *> *frequencyConstraintIDs;

/**
 * Audience JSON
 */
@property(nonatomic, copy, nullable) NSDictionary *audienceJSON;

/**
 * The schedule's message type that will be used for holdout group evaluation
 */
@property(nonatomic, copy, nullable) NSString *messageType;

/**
 * Indicates if the schedule could be in holdout groups
 */
@property(nonatomic, assign) BOOL bypassHoldoutGroups;

/**
 * New user evaluation date
 */
@property(nonatomic, nullable) NSDate *isNewUserEvaluationDate;


@end

NS_ASSUME_NONNULL_END

