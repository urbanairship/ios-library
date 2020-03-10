/* Copyright Airship and Contributors */

#import "UAScreenTrackingEvent+Internal.h"
#import "UAEvent+Internal.h"
#import "UAGlobal.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAScreenTrackingEvent ()

///---------------------------------------------------------------------------------------
/// @name Screen Tracking Event Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The tracking event start time
 */
@property (nonatomic, assign) NSTimeInterval startTime;

/**
 * The tracking event stop time
 */
@property (nonatomic, assign) NSTimeInterval stopTime;

/**
 * The tracking event duration
 */
@property (nonatomic, assign) NSTimeInterval duration;

/**
 * The name of the screen to be tracked
 */
@property (nonatomic, copy) NSString *screen;

/**
 * The name of the previous tracked screen
 */
@property (nonatomic, copy, nullable) NSString *previousScreen;

@end

@implementation UAScreenTrackingEvent

+ (instancetype)eventWithScreen:(NSString *)screen
                 previousScreen:(nullable NSString *)previousScreen
                      startTime:(NSTimeInterval)startTime
                       stopTime:(NSTimeInterval)stopTime {

    UAScreenTrackingEvent *event = [[UAScreenTrackingEvent alloc] init];
    event.screen = screen;
    event.previousScreen = previousScreen;
    event.startTime = startTime;
    event.stopTime = stopTime;

    NSMutableDictionary *mutableEventData = [NSMutableDictionary dictionary];

    [mutableEventData setValue:event.screen forKey:kUAScreenTrackingEventScreenKey];
    [mutableEventData setValue:event.previousScreen forKey:kUAScreenTrackingEventPreviousScreenKey];
    [mutableEventData setValue:[NSString stringWithFormat:@"%0.3f", event.startTime] forKey:kUAScreenTrackingEventEnteredTimeKey];
    [mutableEventData setValue:[NSString stringWithFormat:@"%0.3f", event.stopTime] forKey:kUAScreenTrackingEventExitedTimeKey];
    [mutableEventData setValue:[NSString stringWithFormat:@"%0.3f", event.duration] forKey:kUAScreenTrackingEventDurationKey];

    event.eventData = mutableEventData;
    
    return event;
}

- (BOOL)isValid {
    if (![UAScreenTrackingEvent screenTrackingEventCharacterCountIsValid:self.screen]) {
        UA_LERR(@"Screen name must not be greater than %d characters or less than %d characters in length.", kUAScreenTrackingEventMaxCharacters, kUAScreenTrackingEventMinCharacters);
        return NO;
    }

    // Return early if tracking duration is < 0
    if (self.duration <= 0) {
        UA_LERR(@"Screen tracking duration must be positive.");
        return NO;
    }

    return YES;
}

- (NSString *)eventType {
    return kUAScreenTrackingEventType;
}

- (NSTimeInterval)duration {
    if (!self.stopTime) {
        UA_LERR(@"Duration is not available without a stop time.");
        return 0;
    }

    return self.stopTime - self.startTime;
}

+ (BOOL)screenTrackingEventCharacterCountIsValid:(NSString *)string {
    if (!string || string.length > kUAScreenTrackingEventMaxCharacters || string.length < kUAScreenTrackingEventMinCharacters) {
        return NO;
    }

    return YES;
}

@end

NS_ASSUME_NONNULL_END
