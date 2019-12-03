/* Copyright Airship and Contributors */

#if __has_include(<AirshipCore/AirshipCore.h>)
#import <AirshipCore/AirshipCore.h>
#else
#import "UAAppStateTracker.h"
#endif

#import "UALocationEvent.h"


@interface UALocationInfo ()
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) double horizontalAccuracy;
@property (nonatomic, assign) double verticalAccuracy;
@end

@implementation UALocationInfo

- (instancetype)initWithLatitude:(double)latitude
                       longitude:(double)longitude
              horizontalAccuracy:(double)horizontalAccuracy
                verticalAccuracy:(double)verticalAccuracy {

    self = [super init];

    if (self) {
        self.latitude = latitude;
        self.longitude = longitude;
        self.horizontalAccuracy = horizontalAccuracy;
        self.verticalAccuracy = verticalAccuracy;
    }

    return self;
}

+ (instancetype)infoWithLatitude:(double)latitude
                       longitude:(double)longitude
              horizontalAccuracy:(double)horizontalAccuracy
                verticalAccuracy:(double)verticalAccuracy {

    return [[self alloc] initWithLatitude:latitude
                                longitude:longitude
                       horizontalAccuracy:horizontalAccuracy
                         verticalAccuracy:verticalAccuracy];
}

@end

@interface UALocationEvent()
@property (nonatomic, strong) NSDictionary *eventData;
@end

@implementation UALocationEvent

UALocationEventAnalyticsKey * const UALocationEventForegroundKey = @"foreground";
UALocationEventAnalyticsKey * const UALocationEventLatitudeKey = @"lat";
UALocationEventAnalyticsKey * const UALocationEventLongitudeKey = @"long";
UALocationEventAnalyticsKey * const UALocationEventDesiredAccuracyKey = @"requested_accuracy";
UALocationEventAnalyticsKey * const UALocationEventUpdateTypeKey = @"update_type";
UALocationEventAnalyticsKey * const UALocationEventProviderKey = @"provider";
UALocationEventAnalyticsKey * const UALocationEventDistanceFilterKey = @"update_dist";
UALocationEventAnalyticsKey * const UALocationEventHorizontalAccuracyKey = @"h_accuracy";
UALocationEventAnalyticsKey * const UALocationEventVerticalAccuracyKey = @"v_accuracy";

UALocationEventUpdateType * const UALocationEventAnalyticsType = @"location";
UALocationEventUpdateType * const UALocationEventUpdateTypeChange = @"CHANGE";
UALocationEventUpdateType * const UALocationEventUpdateTypeContinuous = @"CONTINUOUS";
UALocationEventUpdateType * const UALocationEventUpdateTypeSingle = @"SINGLE";
UALocationEventUpdateType * const UALocationEventUpdateTypeNone = @"NONE";

UALocationServiceProviderType *const UALocationServiceProviderGps = @"GPS";
UALocationServiceProviderType *const UALocationServiceProviderNetwork = @"NETWORK";
UALocationServiceProviderType *const UALocationServiceProviderUnknown = @"UNKNOWN";

NSString * const UAAnalyticsValueNone = @"NONE";

+ (UALocationEvent *)locationEventWithInfo:(UALocationInfo *)info
                              providerType:(UALocationServiceProviderType *)providerType
                           desiredAccuracy:(NSNumber *)desiredAccuracy
                            distanceFilter:(NSNumber *)distanceFilter
                                updateType:(UALocationEventUpdateType *)updateType {

    UALocationEvent *event = [[UALocationEvent alloc] init];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    [dict setValue:updateType forKey:UALocationEventUpdateTypeKey];
    [dict setValue:[NSString stringWithFormat:@"%.7f", info.latitude] forKey:UALocationEventLatitudeKey];
    [dict setValue:[NSString stringWithFormat:@"%.7f", info.longitude] forKey:UALocationEventLongitudeKey];
    [dict setValue:[NSString stringWithFormat:@"%li", (long)info.horizontalAccuracy] forKey:UALocationEventHorizontalAccuracyKey];
    [dict setValue:[NSString stringWithFormat:@"%li", (long)info.verticalAccuracy] forKey:UALocationEventVerticalAccuracyKey];

    if (providerType) {
        [dict setValue:providerType forKey:UALocationEventProviderKey];
    } else {
        [dict setValue:UALocationServiceProviderUnknown forKey:UALocationEventProviderKey];
    }

    if (desiredAccuracy) {
        [dict setValue:[NSString stringWithFormat:@"%i", [desiredAccuracy intValue]] forKey:UALocationEventDesiredAccuracyKey];
    } else {
        [dict setValue:UAAnalyticsValueNone forKey:UALocationEventDesiredAccuracyKey];
    }

    if (distanceFilter) {
        [dict setValue:[NSString stringWithFormat:@"%i", [distanceFilter intValue]] forKey:UALocationEventDistanceFilterKey];
    } else {
        [dict setValue:UAAnalyticsValueNone forKey:UALocationEventDistanceFilterKey];
    }

    if ([UAAppStateTracker shared].state == UAApplicationStateActive) {
        [dict setValue:@"true" forKey:UALocationEventForegroundKey];
    } else {
        [dict setValue:@"false" forKey:UALocationEventForegroundKey];
    }

    event.eventData = [dict mutableCopy];

    return event;
}

+ (UALocationEvent *)locationEventWithInfo:(UALocationInfo *)info
                              providerType:(UALocationServiceProviderType *)providerType
                           desiredAccuracy:(NSNumber *)desiredAccuracy
                            distanceFilter:(NSNumber *)distanceFilter {

    return [UALocationEvent locationEventWithInfo:info
                                     providerType:providerType
                                  desiredAccuracy:desiredAccuracy
                                   distanceFilter:distanceFilter
                                       updateType:UALocationEventUpdateTypeNone];

}

+ (UALocationEvent *)singleLocationEventWithInfo:(UALocationInfo *)info
                                    providerType:(UALocationServiceProviderType *)providerType
                                 desiredAccuracy:(NSNumber *)desiredAccuracy
                                  distanceFilter:(NSNumber *)distanceFilter {

    return [UALocationEvent locationEventWithInfo:info
                                     providerType:providerType
                                  desiredAccuracy:desiredAccuracy
                                   distanceFilter:distanceFilter
                                       updateType:UALocationEventUpdateTypeSingle];
}

+ (UALocationEvent *)significantChangeLocationEventWithInfo:(UALocationInfo *)info
                                               providerType:(UALocationServiceProviderType *)providerType {

    return [UALocationEvent locationEventWithInfo:info
                                     providerType:providerType
                                  desiredAccuracy:nil
                                   distanceFilter:nil
                                       updateType:UALocationEventUpdateTypeChange];
}

+ (UALocationEvent *)standardLocationEventWithInfo:(UALocationInfo *)info
                                      providerType:(UALocationServiceProviderType *)providerType
                                   desiredAccuracy:(NSNumber *)desiredAccuracy
                                    distanceFilter:(NSNumber *)distanceFilter {

    return [UALocationEvent locationEventWithInfo:info
                                     providerType:providerType
                                  desiredAccuracy:desiredAccuracy
                                   distanceFilter:distanceFilter
                                       updateType:UALocationEventUpdateTypeContinuous];
}

- (NSString *)eventType {
    return UALocationEventAnalyticsType;
}

- (UAEventPriority)priority {
    return UAEventPriorityLow;
}

- (NSDictionary *)data {
    return self.eventData;
}

@end
