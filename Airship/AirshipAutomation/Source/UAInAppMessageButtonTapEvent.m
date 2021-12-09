/* Copyright Airship and Contributors */

#import "UAInAppMessageButtonTapEvent+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSString *const UAInAppMessageButtonTapEventType = @"in_app_button_tap";
NSString *const UAInAppMessageButtonTapEventButtonIDKey = @"button_identifier";

@interface UAInAppMessageButtonTapEvent()
@property(nonatomic, copy) NSDictionary *eventData;
@end

@implementation UAInAppMessageButtonTapEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message
                      messageID:(NSString *)messageID
               buttonIdentifier:(NSString *)buttonID
               reportingContext:(NSDictionary *)reportingContext
                      campaigns:(NSDictionary *)campaigns {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessage:message messageID:messageID context:reportingContext campaigns:campaigns];
        [mutableEventData setValue:buttonID forKey:UAInAppMessageButtonTapEventButtonIDKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                buttonIdentifier:(NSString *)buttonID
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(NSDictionary *)campaigns{
    return [[self alloc] initWithMessage:message
                               messageID:messageID
                        buttonIdentifier:buttonID
                        reportingContext:reportingContext
                               campaigns:campaigns];
}

- (NSString *)eventType {
    return UAInAppMessageButtonTapEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

@end
