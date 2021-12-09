/* Copyright Airship and Contributors */

#import "UAInAppMessagePageSwipeEvent+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSString *const UAInAppMessagePageSwipeEventType = @"in_app_page_swipe";
NSString *const UAInAppMessagePageSwipeEventPagerIDKey = @"pager_identifier";
NSString *const UAInAppMessagePageSwipeEventFromIndexKey = @"from_page_index";
NSString *const UAInAppMessagePageSwipeEventToIndexKey = @"to_page_index";

@interface UAInAppMessagePageSwipeEvent()
@property(nonatomic, copy) NSDictionary *eventData;
@end

@implementation UAInAppMessagePageSwipeEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message
                      messageID:(NSString *)messageID
                pagerIdentifier:(NSString *)pagerID
                      fromIndex:(NSInteger)fromIndex
                      toIndex:(NSInteger)toIndex
               reportingContext:(NSDictionary *)reportingContext
                      campaigns:(NSDictionary *)campaigns{
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessage:message messageID:messageID context:reportingContext campaigns:campaigns];
        [mutableEventData setValue:pagerID forKey:UAInAppMessagePageSwipeEventPagerIDKey];
        [mutableEventData setValue:@(fromIndex) forKey:UAInAppMessagePageSwipeEventFromIndexKey];
        [mutableEventData setValue:@(toIndex) forKey:UAInAppMessagePageSwipeEventToIndexKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                 pagerIdentifier:(NSString *)pagerID
                       fromIndex:(NSInteger)fromIndex
                       toIndex:(NSInteger)toIndex
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(NSDictionary *)campaigns {
    
    return [[self alloc] initWithMessage:message
                               messageID:messageID
                         pagerIdentifier:pagerID
                               fromIndex:fromIndex
                               toIndex:toIndex
                        reportingContext:reportingContext
                               campaigns:campaigns];
}


- (NSString *)eventType {
    return UAInAppMessagePageSwipeEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

@end
