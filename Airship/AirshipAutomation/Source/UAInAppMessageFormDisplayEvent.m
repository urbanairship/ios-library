/* Copyright Airship and Contributors */

#import "UAInAppMessageFormDisplayEvent+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSString *const UAInAppMessageFormDisplayEventType = @"in_app_form_display";
NSString *const UAInAppMessageFormDisplayEventFormIdentifierKey = @"form_identifier";

@interface UAInAppMessageFormDisplayEvent()
@property(nonatomic, copy) NSDictionary *eventData;
@end

@implementation UAInAppMessageFormDisplayEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message
                      messageID:(NSString *)messageID
                 formIdentifier:(NSString *)formID
               reportingContext:(NSDictionary *)reportingContext
                      campaigns:(NSDictionary *)campaigns {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessage:message messageID:messageID context:reportingContext campaigns:campaigns];
        [mutableEventData setValue:formID forKey:UAInAppMessageFormDisplayEventFormIdentifierKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                  formIdentifier:(NSString *)formID
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(NSDictionary *)campaigns{
    return [[self alloc] initWithMessage:message
                               messageID:messageID
                          formIdentifier:formID
                        reportingContext:reportingContext
                               campaigns:campaigns];
}

- (NSString *)eventType {
    return UAInAppMessageFormDisplayEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

@end
