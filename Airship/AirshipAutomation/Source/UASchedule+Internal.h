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
@interface UASchedule ()

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

@end

NS_ASSUME_NONNULL_END

