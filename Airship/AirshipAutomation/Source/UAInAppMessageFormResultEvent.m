/* Copyright Airship and Contributors */

#import "UAInAppMessageFormResultEvent+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSString *const UAInAppMessageFormResultEventType = @"in_app_form_result";
NSString *const UAInAppMessageFormResultEventFormsKey = @"forms";
NSString *const UAInAppMessageFormResultEventFormIdentifierKey = @"form_identifier";

@interface UAInAppMessageFormResultEvent()
@property(nonatomic, copy) NSDictionary *eventData;
@end

@implementation UAInAppMessageFormResultEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message
                      messageID:(NSString *)messageID
                 formIdentifier:(NSString *)formID
                       formData:(NSDictionary *)formData
               reportingContext:(NSDictionary *)reportingContext
                      campaigns:(NSDictionary *)campaigns {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessage:message messageID:messageID context:reportingContext campaigns:campaigns];
        [mutableEventData setValue:formID forKey:UAInAppMessageFormResultEventFormIdentifierKey];
        [mutableEventData setValue:formData forKey:UAInAppMessageFormResultEventFormsKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                  formIdentifier:(NSString *)formID
                        formData:(NSDictionary *)formData
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(NSDictionary *)campaigns {
    return [[self alloc] initWithMessage:message
                               messageID:messageID
                          formIdentifier:formID
                                formData:formData
                        reportingContext:reportingContext
                               campaigns:campaigns];
}

- (NSString *)eventType {
    return UAInAppMessageFormResultEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

@end
