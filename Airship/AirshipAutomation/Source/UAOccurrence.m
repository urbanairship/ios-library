/* Copyright Airship and Contributors */

#import "UAOccurrence+Internal.h"

@interface UAOccurrence ()
@property(nonatomic, copy) NSString *parentConstraintID;
@property(nonatomic, strong) NSDate *timestamp;
@end

@implementation UAOccurrence

+ (instancetype)occurrenceWithParentConstraintID:(NSString *)parentConstrantID
                                       timestamp:(NSDate *)timestamp {
    UAOccurrence *occurrence = [[self alloc] init];
    occurrence.parentConstraintID = parentConstrantID;
    occurrence.timestamp = timestamp;

    return occurrence;
}

@end
