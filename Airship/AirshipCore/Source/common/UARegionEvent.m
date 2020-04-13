/* Copyright Airship and Contributors */

#import "UARegionEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAProximityRegion+Internal.h"
#import "UACircularRegion+Internal.h"
#import "UAGlobal.h"

@implementation UARegionEvent

NSString * const UARegionEventType = @"region_event";
double const UARegionEventMaxLatitude = 90;
double const UARegionEventMinLatitude = -90;
double const UARegionEventMaxLongitude = 180;
double const UARegionEventMinLongitude = -180;
NSUInteger const UARegionEventMaxCharacters = 255;
NSUInteger const UARegionEventMinCharacters = 1;
NSString * const UARegionSourceKey = @"source";
NSString * const UARegionIDKey = @"region_id";
NSString * const UARegionBoundaryEventKey = @"action";
NSString * const UARegionBoundaryEventEnterValue = @"enter";
NSString * const UARegionBoundaryEventExitValue = @"exit";
NSString * const UARegionLatitudeKey = @"latitude";
NSString * const UARegionLongitudeKey = @"longitude";
NSString * const UAProximityRegionKey = @"proximity";
NSString * const UAProximityRegionIDKey = @"proximity_id";
NSString * const UAProximityRegionMajorKey = @"major";
NSString * const UAProximityRegionMinorKey = @"minor";
NSString * const UAProximityRegionRSSIKey = @"rssi";
NSString * const UACircularRegionKey = @"circular_region";
NSString * const UACircularRegionRadiusKey = @"radius";
NSString * const kUARegionEventType = UARegionEventType; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventType.
double const kUARegionEventMaxLatitude = UARegionEventMaxLatitude; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxLatitude.
double const kUARegionEventMinLatitude = UARegionEventMinLatitude; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinLatitude.
double const kUARegionEventMaxLongitude = UARegionEventMaxLongitude; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxLongitude.
double const kUARegionEventMinLongitude = UARegionEventMinLongitude; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinLongitude.
NSUInteger const kUARegionEventMaxCharacters = UARegionEventMaxCharacters; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMaxCharacters.
NSUInteger const kUARegionEventMinCharacters = UARegionEventMinCharacters; // Deprecated – to be removed in SDK version 14.0. Please use UARegionEventMinCharacters.
NSString * const kUARegionSourceKey = UARegionSourceKey; // Deprecated – to be removed in SDK version 14.0. Please use UARegionSourceKey.
NSString * const kUARegionIDKey = UARegionIDKey; // Deprecated – to be removed in SDK version 14.0. Please use UARegionIDKey.
NSString * const kUARegionBoundaryEventKey = UARegionBoundaryEventKey; // Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventKey.
NSString * const kUARegionBoundaryEventEnterValue = UARegionBoundaryEventEnterValue; // Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventEnterValue.
NSString * const kUARegionBoundaryEventExitValue = UARegionBoundaryEventExitValue; // Deprecated – to be removed in SDK version 14.0. Please use UARegionBoundaryEventExitValue.
NSString * const kUARegionLatitudeKey = UARegionLatitudeKey; // Deprecated – to be removed in SDK version 14.0. Please use UARegionLatitudeKey.
NSString * const kUARegionLongitudeKey = UARegionLongitudeKey; // Deprecated – to be removed in SDK version 14.0. Please use UARegionLongitudeKey.
NSString * const kUAProximityRegionKey = UAProximityRegionKey; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionKey.
NSString * const kUAProximityRegionIDKey = UAProximityRegionIDKey; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionIDKey.
NSString * const kUAProximityRegionMajorKey = UAProximityRegionMajorKey; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMajorKey.
NSString * const kUAProximityRegionMinorKey = UAProximityRegionMinorKey; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionMinorKey.
NSString * const kUAProximityRegionRSSIKey = UAProximityRegionRSSIKey; // Deprecated – to be removed in SDK version 14.0. Please use UAProximityRegionRSSIKey.
NSString * const kUACircularRegionKey = UACircularRegionKey; // Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionKey.
NSString * const kUACircularRegionRadiusKey = UACircularRegionRadiusKey; // Deprecated – to be removed in SDK version 14.0. Please use UACircularRegionRadiusKey.

- (NSString *)eventType {
    return UARegionEventType;
}

- (UAEventPriority)priority {
    return UAEventPriorityHigh;
}

- (BOOL)isValid {
    if (![UARegionEvent regionEventCharacterCountIsValid:self.regionID]) {
        UA_LERR(@"Region ID must not be greater than %ld characters or less than %ld character in length.", (unsigned long) UARegionEventMaxCharacters, (unsigned long) UARegionEventMinCharacters);
        return NO;
    }

    if (![UARegionEvent regionEventCharacterCountIsValid:self.source]) {
        UA_LERR(@"Region source must not be greater than %ld characters or less than %ld character in length.", (unsigned long) UARegionEventMaxCharacters, (unsigned long) UARegionEventMinCharacters);
        return NO;
    }

    if (!(self.boundaryEvent == UABoundaryEventEnter || self.boundaryEvent == UABoundaryEventExit)) {
        UA_LERR(@"Region boundary event must be an enter or exit type.");
        return NO;
    }

    return YES;
}

+ (instancetype)regionEventWithRegionID:(NSString *)regionID source:(NSString *)source boundaryEvent:(UABoundaryEvent)boundaryEvent{
    UARegionEvent *regionEvent = [[self alloc] init];

    regionEvent.source = source;
    regionEvent.regionID = regionID;
    regionEvent.boundaryEvent = boundaryEvent;

    if (![regionEvent isValid]) {
        return nil;
    }

    return regionEvent;
}

- (NSDictionary *)data {
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary *proximityDictionary;
    NSMutableDictionary *circularRegionDictionary;;

    [dictionary setValue:self.source forKey:UARegionSourceKey];
    [dictionary setValue:self.regionID forKey:UARegionIDKey];

    if (self.boundaryEvent == UABoundaryEventEnter) {
        [dictionary setValue:UARegionBoundaryEventEnterValue forKey:UARegionBoundaryEventKey];
    }
    
    if (self.boundaryEvent == UABoundaryEventExit) {
        [dictionary setValue:UARegionBoundaryEventExitValue forKey:UARegionBoundaryEventKey];
    }

    if (self.proximityRegion.isValid) {
        proximityDictionary = [NSMutableDictionary dictionary];

        [proximityDictionary setValue:self.proximityRegion.proximityID forKey:UAProximityRegionIDKey];
        [proximityDictionary setValue:self.proximityRegion.major forKey:UAProximityRegionMajorKey];
        [proximityDictionary setValue:self.proximityRegion.minor forKey:UAProximityRegionMinorKey];

        if (self.proximityRegion.RSSI) {
            [proximityDictionary setValue:self.proximityRegion.RSSI forKey:UAProximityRegionRSSIKey];
        }

        if (self.proximityRegion.latitude && self.proximityRegion.longitude) {
            [proximityDictionary setValue:[NSString stringWithFormat:@"%.7f", self.proximityRegion.latitude.doubleValue] forKey:UARegionLatitudeKey];
            [proximityDictionary setValue:[NSString stringWithFormat:@"%.7f", self.proximityRegion.longitude.doubleValue] forKey:UARegionLongitudeKey];
        }

        [dictionary setValue:proximityDictionary forKey:UAProximityRegionKey];
    }

    if (self.circularRegion.isValid) {
        circularRegionDictionary = [NSMutableDictionary dictionary];

        [circularRegionDictionary setValue:[NSString stringWithFormat:@"%.1f", self.circularRegion.radius.doubleValue] forKey:UACircularRegionRadiusKey];
        [circularRegionDictionary setValue:[NSString stringWithFormat:@"%.7f", self.circularRegion.latitude.doubleValue] forKey:UARegionLatitudeKey];
        [circularRegionDictionary setValue:[NSString stringWithFormat:@"%.7f", self.circularRegion.longitude.doubleValue] forKey:UARegionLongitudeKey];

        [dictionary setValue:circularRegionDictionary forKey:UACircularRegionKey];
    }

    return dictionary;
}


- (NSDictionary *)payload {
    /*
     * We are unable to use the event.data for automation because we modify some
     * values to be stringified versions before we store the event to be sent to
     * warp9. Instead we are going to recreate the event data with the unmodified
     * values.
     */

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSMutableDictionary *proximityDictionary;
    NSMutableDictionary *circularRegionDictionary;;

    [dictionary setValue:self.source forKey:UARegionSourceKey];
    [dictionary setValue:self.regionID forKey:UARegionIDKey];

    if (self.boundaryEvent == UABoundaryEventEnter) {
        [dictionary setValue:UARegionBoundaryEventEnterValue forKey:UARegionBoundaryEventKey];
    }

    if (self.boundaryEvent == UABoundaryEventExit) {
        [dictionary setValue:UARegionBoundaryEventExitValue forKey:UARegionBoundaryEventKey];
    }

    if (self.proximityRegion) {
        proximityDictionary = [NSMutableDictionary dictionary];

        [proximityDictionary setValue:self.proximityRegion.proximityID forKey:UAProximityRegionIDKey];
        [proximityDictionary setValue:self.proximityRegion.major forKey:UAProximityRegionMajorKey];
        [proximityDictionary setValue:self.proximityRegion.minor forKey:UAProximityRegionMinorKey];

        if (self.proximityRegion.RSSI) {
            [proximityDictionary setValue:self.proximityRegion.RSSI forKey:UAProximityRegionRSSIKey];
        }

        if (self.proximityRegion.latitude && self.proximityRegion.longitude) {
            [proximityDictionary setValue:self.proximityRegion.latitude forKey:UARegionLatitudeKey];
            [proximityDictionary setValue:self.proximityRegion.longitude forKey:UARegionLongitudeKey];
        }

        [dictionary setValue:proximityDictionary forKey:UAProximityRegionKey];
    }

    if (self.circularRegion) {
        circularRegionDictionary = [NSMutableDictionary dictionary];
        [circularRegionDictionary setValue:self.circularRegion.radius forKey:UACircularRegionRadiusKey];
        [circularRegionDictionary setValue:self.circularRegion.latitude forKey:UARegionLatitudeKey];
        [circularRegionDictionary setValue:self.circularRegion.longitude forKey:UARegionLongitudeKey];
        [dictionary setValue:circularRegionDictionary forKey:UACircularRegionKey];
    }
    
    return dictionary;
}

+ (BOOL)regionEventRSSIIsValid:(NSNumber *)RSSI {
    if (!RSSI || RSSI.doubleValue > UAProximityRegionMaxRSSI || RSSI.doubleValue < UAProximityRegionMinRSSI) {
        return NO;
    }

    return YES;
}

+ (BOOL)regionEventRadiusIsValid:(NSNumber *)radius {
    if (!radius || radius.doubleValue > UACircularRegionMaxRadius || radius.doubleValue < UACircularRegionMinRadius) {
        return NO;
    }

    return YES;
}

+ (BOOL)regionEventLatitudeIsValid:(NSNumber *)latitude {
    if (!latitude || latitude.doubleValue > UARegionEventMaxLatitude || latitude.doubleValue < UARegionEventMinLatitude) {
        return NO;
    }

    return YES;
}

+ (BOOL)regionEventLongitudeIsValid:(NSNumber *)longitude {
    if (!longitude || longitude.doubleValue > UARegionEventMaxLongitude || longitude.doubleValue < UARegionEventMinLongitude) {
        return NO;
    }

    return YES;
}

+ (BOOL)regionEventCharacterCountIsValid:(NSString *)string {
    if (!string || string.length > UARegionEventMaxCharacters || string.length < UARegionEventMinCharacters) {
        return NO;
    }
    
    return YES;
}

@end
