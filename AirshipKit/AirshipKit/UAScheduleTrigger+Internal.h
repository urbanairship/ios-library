/* Copyright 2017 Urban Airship and Contributors */

#import "UAScheduleTrigger.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAScheduleTrigger ()

@property(nonatomic, assign) UAScheduleTriggerType type;
@property(nonatomic, strong) NSNumber *goal;
@property(nonatomic, strong, nullable) UAJSONPredicate *predicate;

+(instancetype)triggerWithType:(UAScheduleTriggerType)type
                          goal:(NSNumber *)goal
                     predicate:(nullable UAJSONPredicate *)predicate;

@end

NS_ASSUME_NONNULL_END
