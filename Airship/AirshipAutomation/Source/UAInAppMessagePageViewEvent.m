/* Copyright Airship and Contributors */

#import "UAInAppMessagePageViewEvent+Internal.h"
#import "UAAirshipAutomationCoreImport.h"
#import "UAInAppMessageEventUtils+Internal.h"

NSString *const UAInAppMessagePageViewEventType = @"in_app_page_view";
NSString *const UAInAppMessagePageViewEventPagerIDKey = @"pager_identifier";
NSString *const UAInAppMessagePageViewEventPageIndexKey = @"page_index";
NSString *const UAInAppMessagePageViewEventPageCountKey = @"page_count";
NSString *const UAInAppMessagePageViewEventCompletedKey = @"completed";

@interface UAInAppMessagePageViewEvent()
@property(nonatomic, copy) NSDictionary *eventData;
@end

@implementation UAInAppMessagePageViewEvent

- (instancetype)initWithMessage:(UAInAppMessage *)message
                      messageID:(NSString *)messageID
                pagerIdentifier:(NSString *)pagerID
                      pageIndex:(NSInteger)pageIndex
                      pageCount:(NSInteger)pageCount
                      completed:(BOOL)completed
               reportingContext:(NSDictionary *)reportingContext
                      campaigns:(NSDictionary *)campaigns {
    self = [super init];
    if (self) {
        NSMutableDictionary *mutableEventData = [UAInAppMessageEventUtils createDataWithMessage:message messageID:messageID context:reportingContext campaigns:campaigns];
        [mutableEventData setValue:pagerID forKey:UAInAppMessagePageViewEventPagerIDKey];
        [mutableEventData setValue:@(pageCount) forKey:UAInAppMessagePageViewEventPageCountKey];
        [mutableEventData setValue:@(pageIndex) forKey:UAInAppMessagePageViewEventPageIndexKey];
        [mutableEventData setValue:@(completed) forKey:UAInAppMessagePageViewEventCompletedKey];
        self.eventData = mutableEventData;
        return self;
    }
    return nil;
}

+ (instancetype)eventWithMessage:(UAInAppMessage *)message
                       messageID:(NSString *)messageID
                 pagerIdentifier:(NSString *)pagerID
                       pageIndex:(NSInteger)pageIndex
                       pageCount:(NSInteger)pageCount
                       completed:(BOOL)completed
                reportingContext:(NSDictionary *)reportingContext
                       campaigns:(NSDictionary *)campaigns {
    return [[self alloc] initWithMessage:message
                               messageID:messageID
                         pagerIdentifier:pagerID
                               pageIndex:pageIndex
                               pageCount:pageCount
                               completed:completed
                        reportingContext:reportingContext
                               campaigns:campaigns];
}

- (NSString *)eventType {
    return UAInAppMessagePageViewEventType;
}

- (NSDictionary *)data {
    return self.eventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}

@end
