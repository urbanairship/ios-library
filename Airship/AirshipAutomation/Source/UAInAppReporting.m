#import "UAInAppReporting+Internal.h"
#import "UAInAppMessage+Internal.h"
#import "UAAirshipAutomationCoreImport.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

// Common
NSString *const UAInAppMessageEventIDKey = @"id";
NSString *const UAInAppMessageEventConversionSendIDKey = @"conversion_send_id";
NSString *const UAInAppMessageEventConversionMetadataKey = @"conversion_metadata";
NSString *const UAInAppMessageEventSourceKey = @"source";
NSString *const UAInAppMessageEventMessageIDKey = @"message_id";
NSString *const UAInAppMessageEventCampaignsKey = @"campaigns";
NSString *const UAInAppMessageEventLocaleKey = @"locale";
NSString *const UAInAppMessageEventUrbanAirshipSourceValue = @"urban-airship";
NSString *const UAInAppMessageEventAppDefinedSourceValue = @"app-defined";
NSString *const UAInAppMessageDisplayEventLocaleKey = @"locale";

// Context
NSString *const UAInAppMessageEventContextKey = @"context";
NSString *const UAInAppMessageEventReportingContextKey = @"reporting_context";
NSString *const UAInAppMessagePagerContextKey = @"pager";
NSString *const UAInAppMessagePagerContextIDKey = @"identifier";
NSString *const UAInAppMessagePagerContextPageIDKey = @"page_identifier";
NSString *const UAInAppMessagePagerContextPageIndexKey = @"page_index";
NSString *const UAInAppMessagePagerContextCompletedKey = @"completed";
NSString *const UAInAppMessagePagerContextCountKey = @"count";
NSString *const UAInAppMessageFormContextKey = @"form";
NSString *const UAInAppMessageFormContextIDKey = @"identifier";
NSString *const UAInAppMessageFormContextSubmittedKey = @"submitted";
NSString *const UAInAppMessageFormContextTypeKey = @"type";
NSString *const UAInAppMessageFormContextResponseTypeKey = @"response_type";
NSString *const UAInAppMessageButtonContextKey = @"button";
NSString *const UAInAppMessageButtonContextIDKey = @"identifier";


// Display
NSString *const UAInAppMessageDisplayEventType = @"in_app_display";


// Resolution
NSString *const UAInAppMessageResolutionEventType = @"in_app_resolution";
NSString *const UAInAppMessageResolutionEventTypeKey = @"type";
NSString *const UAInAppMessageResolutionEventResolutionKey = @"resolution";
NSString *const UAInAppMessageResolutionEventDisplayTimeKey = @"display_time";
NSString *const UAInAppMessageResolutionEventButtonIDKey = @"button_id";
NSString *const UAInAppMessageResolutionEventButtonDescriptionKey = @"button_description";
NSString *const UAInAppMessageResolutionEventReplacementIDKey = @"replacement_id";
NSString *const UAInAppMessageResolutionEventReplaced = @"replaced";
NSString *const UAInAppMessageResolutionEventDirectOpen = @"direct_open";
NSString *const UAInAppMessageResolutionEventMessageClick = @"message_click";
NSString *const UAInAppMessageResolutionEventButtonClick = @"button_click";
NSString *const UAInAppMessageResolutionEventUserDismissed = @"user_dismissed";
NSString *const UAInAppMessageResolutionEventTimedOut = @"timed_out";

// Button tap
NSString *const UAInAppMessageButtonTapEventType = @"in_app_button_tap";
NSString *const UAInAppMessageButtonTapEventButtonIDKey = @"button_identifier";

// Pager summary
NSString *const UAInAppMessagePageSummaryEventType = @"in_app_pager_summary";
NSString *const UAInAppMessagePageSummaryEventPagerIDKey = @"pager_identifier";
NSString *const UAInAppMessagePageSummaryEventViewedPagesKey = @"viewed_pages";
NSString *const UAInAppMessagePageSummaryEventPageCountKey = @"page_count";
NSString *const UAInAppMessagePageSummaryEventCompletedKey = @"completed";

NSString *const UAInAppPagerSummaryIndexKey = @"page_index";
NSString *const UAInAppPagerSummaryDurationKey = @"display_time";
NSString *const UAInAppPagerSummaryIDKey = @"page_identifier";

// Pager complete
NSString *const UAInAppMessagePageCompletedEventType = @"in_app_pager_completed";
NSString *const UAInAppMessagePageCompletedEventPagerIDKey = @"pager_identifier";
NSString *const UAInAppMessagePageCompletedEventPageIndexKey = @"page_index";
NSString *const UAInAppMessagePageCompletedEventPageCountKey = @"page_count";
NSString *const UAInAppMessagePageCompletedEventPageIDKey = @"page_identifier";


// Pager view

NSString *const UAInAppMessagePageViewEventType = @"in_app_page_view";
NSString *const UAInAppMessagePageViewEventPagerIDKey = @"pager_identifier";
NSString *const UAInAppMessagePageViewEventPageIDKey = @"page_identifier";
NSString *const UAInAppMessagePageViewEventPageIndexKey = @"page_index";
NSString *const UAInAppMessagePageViewEventPageCountKey = @"page_count";
NSString *const UAInAppMessagePageViewEventCompletedKey = @"completed";
NSString *const UAInAppMessagePageViewEventViewedCountKey = @"viewed_count";

// Page swipe
NSString *const UAInAppMessagePageSwipeEventType = @"in_app_page_swipe";
NSString *const UAInAppMessagePageSwipeEventPagerIDKey = @"pager_identifier";
NSString *const UAInAppMessagePageSwipeEventFromIndexKey = @"from_page_index";
NSString *const UAInAppMessagePageSwipeEventToIndexKey = @"to_page_index";
NSString *const UAInAppMessagePageSwipeEventFromPageIDKey = @"from_page_identifier";
NSString *const UAInAppMessagePageSwipeEventToPageIDKey = @"to_page_identifier";

// Permission
NSString *const UAInAppMessagePermissionResultEventType = @"in_app_permission_result";
NSString *const UAInAppMessagePermissionResultEventPermissionKey = @"permission";
NSString *const UAInAppMessagePermissionResultEventStartingStatusKey = @"starting_permission_status";
NSString *const UAInAppMessagePermissionResultEventEndingStatusKey = @"ending_permission_status";

// Form result
NSString *const UAInAppMessageFormResultEventType = @"in_app_form_result";
NSString *const UAInAppMessageFormResultEventFormsKey = @"forms";

// Form display
NSString *const UAInAppMessageFormDisplayEventType = @"in_app_form_display";
NSString *const UAInAppMessageFormDisplayEventFormIdentifierKey = @"form_identifier";
NSString *const UAInAppMessageFormDisplayEventFormTypeKey = @"form_type";
NSString *const UAInAppMessageFormDisplayEventFormResponseTypeKey = @"form_response_type";


@interface UAInAppAutomationEvent : NSObject<UAEvent>
@property(nonatomic, copy) NSString *inAppEventType;
@property(nonatomic, copy) NSDictionary *inAppEventData;
@end

@implementation UAInAppAutomationEvent
- (NSString *)eventType {
    return self.inAppEventType;
}

- (NSDictionary *)data {
    return self.inAppEventData;
}

- (UAEventPriority)priority {
    return UAEventPriorityNormal;
}
@end



@interface UAInAppReporting()
@property(nonatomic, copy) NSString *eventType;
@property(nonatomic, copy) NSString *scheduleID;
@property(nonatomic, assign) UAInAppMessageSource source;
@property(nonatomic, copy) NSDictionary *renderedLocale;
@property(nonatomic, copy) NSDictionary *baseData;
@end

@implementation UAInAppReporting
- (instancetype)initWithEventType:(NSString *)eventType
                       scheduleID:(NSString *)scheduleID
                           source:(UAInAppMessageSource)source
                         baseData:(NSDictionary *)baseData {
    self = [super init];
    if (self) {
        self.eventType = eventType;
        self.scheduleID = scheduleID;
        self.source = source;
        self.renderedLocale = nil;
        self.baseData = baseData;
    }
    
    return self;
}

- (instancetype)initWithEventType:(NSString *)eventType
                       scheduleID:(NSString *)scheduleID
                           message:(UAInAppMessage *)message
                         baseData:(NSDictionary *)baseData {
    self = [super init];
    if (self) {
        self.eventType = eventType;
        self.scheduleID = scheduleID;
        self.source = message.source;
        self.renderedLocale = message.renderedLocale;
        self.baseData = baseData;
    }
    
    return self;
}

+ (instancetype)displayEventWithScheduleID:(NSString *)scheduleID
                                   message:(UAInAppMessage *)message {
    return [[self alloc] initWithEventType:UAInAppMessageDisplayEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:nil];
}

+ (instancetype)legacyReplacedEventWithScheduleID:(NSString *)scheduleID
                                    replacementID:(NSString *)replacementID {
    
    NSDictionary *baseData = @{
        UAInAppMessageResolutionEventResolutionKey: @{
            UAInAppMessageResolutionEventTypeKey: UAInAppMessageResolutionEventReplaced,
            UAInAppMessageResolutionEventReplacementIDKey: replacementID ?: @""
        }
    };
    
    return [[self alloc] initWithEventType:UAInAppMessageResolutionEventType
                                scheduleID:scheduleID
                                    source:UAInAppMessageSourceLegacyPush
                                  baseData:baseData];
}

+ (instancetype)legacyDirectOpenEventWithScheduleID:(NSString *)scheduleID {
    NSDictionary *baseData = @{
        UAInAppMessageResolutionEventResolutionKey: @{
            UAInAppMessageResolutionEventTypeKey: UAInAppMessageResolutionEventDirectOpen
        }
    };
    
    return [[self alloc] initWithEventType:UAInAppMessageResolutionEventType
                                scheduleID:scheduleID
                                    source:UAInAppMessageSourceLegacyPush
                                  baseData:baseData];
}



+ (instancetype)interruptedEventWithScheduleID:(NSString *)scheduleID
                                        source:(UAInAppMessageSource)source {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution userDismissedResolution];
    NSDictionary *baseData = @{
        UAInAppMessageResolutionEventResolutionKey: [self createResolutionDataWithResolution:resolution
                                                                                 displayTime:0]
    };
    
    return [[self alloc] initWithEventType:UAInAppMessageResolutionEventType
                                scheduleID:scheduleID
                                    source:source
                                  baseData:baseData];
}

+ (instancetype)resolutionEventWithScheduleID:(NSString *)scheduleID
                                      message:(UAInAppMessage *)message
                                   resolution:(UAInAppMessageResolution *)resolution
                                  displayTime:(NSTimeInterval)displayTime {
    
    NSDictionary *baseData = @{
        UAInAppMessageResolutionEventResolutionKey: [self createResolutionDataWithResolution:resolution
                                                                                 displayTime:displayTime]
    };
    
    return [[self alloc] initWithEventType:UAInAppMessageResolutionEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)buttonTapEventWithScheduleID:(NSString *)scheduleID
                                     message:(UAInAppMessage *)message
                                    buttonID:(NSString *)buttonID {
    NSDictionary *baseData = @{ UAInAppMessageButtonTapEventButtonIDKey : buttonID ?: @"" };
    
    return [[self alloc] initWithEventType:UAInAppMessageButtonTapEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)permissionResultEventWithScheduleID:(NSString *)scheduleID
                                            message:(UAInAppMessage *)message
                                         permission:(NSString *)permission
                                     startingStatus:(NSString *)startingStatus
                                       endingStatus:(NSString *)endingStatus {

    NSDictionary *baseData = @{
        UAInAppMessagePermissionResultEventPermissionKey: permission,
        UAInAppMessagePermissionResultEventStartingStatusKey: startingStatus,
        UAInAppMessagePermissionResultEventEndingStatusKey: endingStatus
    };

    return [[self alloc] initWithEventType:UAInAppMessagePermissionResultEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)pageViewEventWithScheduleID:(NSString *)scheduleID
                                    message:(UAInAppMessage *)message
                                  pagerInfo:(nonnull UAThomasPagerInfo *)pagerInfo
                                  viewCount:(NSUInteger)viewCount {
    NSDictionary *baseData = @{
        UAInAppMessagePageViewEventPagerIDKey : pagerInfo.identifier,
        UAInAppMessagePageViewEventPageCountKey: @(pagerInfo.pageCount),
        UAInAppMessagePageViewEventPageIndexKey: @(pagerInfo.pageIndex),
        UAInAppMessagePageViewEventCompletedKey: @(pagerInfo.completed),
        UAInAppMessagePageViewEventViewedCountKey: @(viewCount),
        UAInAppMessagePageViewEventPageIDKey: pagerInfo.pageIdentifier
    };
    
    return [[self alloc] initWithEventType:UAInAppMessagePageViewEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
    
}

+ (instancetype)pagerCompletedEventWithScheduleID:(NSString *)scheduleID
                                          message:(UAInAppMessage *)message
                                        pagerInfo:(nonnull UAThomasPagerInfo *)pagerInfo {
    
    NSDictionary *baseData = @{
        UAInAppMessagePageCompletedEventPagerIDKey : pagerInfo.identifier,
        UAInAppMessagePageCompletedEventPageIndexKey: @(pagerInfo.pageIndex),
        UAInAppMessagePageCompletedEventPageCountKey: @(pagerInfo.pageCount),
        UAInAppMessagePageCompletedEventPageIDKey: pagerInfo.pageIdentifier
    };
    
    return [[self alloc] initWithEventType:UAInAppMessagePageCompletedEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)pagerSummaryEventWithScehduleID:(NSString *)scheduleID
                                        message:(UAInAppMessage *)message
                                      pagerInfo:(nonnull UAThomasPagerInfo *)pagerInfo
                                    viewedPages:(nonnull NSArray *)viewedPages {
    NSDictionary *baseData = @{
        UAInAppMessagePageSummaryEventPagerIDKey : pagerInfo.identifier,
        UAInAppMessagePageSummaryEventViewedPagesKey: viewedPages,
        UAInAppMessagePageSummaryEventPageCountKey: @(pagerInfo.pageCount),
        UAInAppMessagePageSummaryEventCompletedKey: @(pagerInfo.completed)
    };
    
    return [[self alloc] initWithEventType:UAInAppMessagePageSummaryEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)pageSwipeEventWithScheduleID:(NSString *)scheduleID
                                     message:(UAInAppMessage *)message
                                        from:(UAThomasPagerInfo *)from
                                          to:(UAThomasPagerInfo *)to {
    
    NSDictionary *baseData = @{
        UAInAppMessagePageSwipeEventPagerIDKey : from.identifier,
        UAInAppMessagePageSwipeEventToIndexKey: @(to.pageIndex),
        UAInAppMessagePageSwipeEventToPageIDKey: to.pageIdentifier,
        UAInAppMessagePageSwipeEventFromIndexKey: @(from.pageIndex),
        UAInAppMessagePageSwipeEventFromPageIDKey: from.pageIdentifier
    };
    
    return [[self alloc] initWithEventType:UAInAppMessagePageSwipeEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)formDisplayEventWithScheduleID:(NSString *)scheduleID
                                       message:(UAInAppMessage *)message
                                      formInfo:(nonnull UAThomasFormInfo *)formInfo {
    NSMutableDictionary *baseData = [NSMutableDictionary dictionary];
    [baseData setValue:formInfo.identifier forKey:UAInAppMessageFormDisplayEventFormIdentifierKey];
    [baseData setValue:formInfo.formResponseType forKey:UAInAppMessageFormDisplayEventFormResponseTypeKey];
    [baseData setValue:formInfo.formType forKey:UAInAppMessageFormDisplayEventFormTypeKey];
    
    return [[self alloc] initWithEventType:UAInAppMessageFormDisplayEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (instancetype)formResultEventWithScheduleID:(NSString *)scheduleID
                                       message:(UAInAppMessage *)message
                                   formResult:(nonnull UAThomasFormResult *)formResult {
    
    NSDictionary *baseData = @{
        UAInAppMessageFormResultEventFormsKey : formResult.formData,
    };
    
    return [[self alloc] initWithEventType:UAInAppMessageFormResultEventType
                                scheduleID:scheduleID
                                   message:message
                                  baseData:baseData];
}

+ (id)createIDMapWithMessageID:(NSString *)messageID
                        source:(UAInAppMessageSource)source
                     campaigns:(NSDictionary *)campaigns {

    switch (source) {
        case UAInAppMessageSourceRemoteData: {
            NSMutableDictionary *idMap = [NSMutableDictionary dictionary];
            [idMap setValue:messageID forKey:UAInAppMessageEventMessageIDKey];

            if (campaigns.count) {
                [idMap setValue:campaigns forKey:UAInAppMessageEventCampaignsKey];
            }
            return idMap;
        }

        case UAInAppMessageSourceAppDefined: {
            return @{ UAInAppMessageEventMessageIDKey: messageID };
        }

        case UAInAppMessageSourceLegacyPush:
        default: {
            return messageID;
        }
    }
}


+ (NSDictionary *)createResolutionDataWithResolution:(UAInAppMessageResolution *)resolution
                                         displayTime:(NSTimeInterval)displayTime {

    NSMutableDictionary *resolutionData = [NSMutableDictionary dictionary];
    [resolutionData setValue:[NSString stringWithFormat:@"%.3f", displayTime]
                      forKey:UAInAppMessageResolutionEventDisplayTimeKey];

    switch (resolution.type) {
        case UAInAppMessageResolutionTypeTimedOut:
            [resolutionData setValue:UAInAppMessageResolutionEventTimedOut forKey:UAInAppMessageResolutionEventTypeKey];
            break;

        case UAInAppMessageResolutionTypeButtonClick:
        {
            [resolutionData setValue:UAInAppMessageResolutionEventButtonClick forKey:UAInAppMessageResolutionEventTypeKey];
            [resolutionData setValue:resolution.buttonInfo.identifier forKey:UAInAppMessageResolutionEventButtonIDKey];

            NSString *description = resolution.buttonInfo.label.text;

            [resolutionData setValue:description forKey:UAInAppMessageResolutionEventButtonDescriptionKey];
            break;
        }

        case UAInAppMessageResolutionTypeMessageClick:
            [resolutionData setValue:UAInAppMessageResolutionEventMessageClick forKey:UAInAppMessageResolutionEventTypeKey];
            break;

        case UAInAppMessageResolutionTypeUserDismissed:
            [resolutionData setValue:UAInAppMessageResolutionEventUserDismissed forKey:UAInAppMessageResolutionEventTypeKey];
            break;
    }

    return resolutionData;
}

- (void)record:(id<UAAnalyticsProtocol>)analytics {
    id identifier = [UAInAppReporting createIDMapWithMessageID:self.scheduleID
                                                        source:self.source
                                                     campaigns:self.campaigns];

    NSMutableDictionary *data = [self.baseData mutableCopy] ?: [NSMutableDictionary dictionary];
    [data setValue:identifier forKey:UAInAppMessageEventIDKey];
    [data setValue:analytics.conversionSendID forKey:UAInAppMessageEventConversionSendIDKey];
    [data setValue:analytics.conversionPushMetadata forKey:UAInAppMessageEventConversionMetadataKey];
    [data setValue:self.renderedLocale forKey:UAInAppMessageEventLocaleKey];
    
    NSMutableDictionary *context = [NSMutableDictionary dictionary];
    if (self.layoutContext.pagerInfo) {
        context[UAInAppMessagePagerContextKey] = @{
            UAInAppMessagePagerContextIDKey: self.layoutContext.pagerInfo.identifier,
            UAInAppMessagePagerContextPageIDKey: self.layoutContext.pagerInfo.pageIdentifier,
            UAInAppMessagePagerContextPageIndexKey: @(self.layoutContext.pagerInfo.pageIndex),
            UAInAppMessagePagerContextCompletedKey: @(self.layoutContext.pagerInfo.completed),
            UAInAppMessagePagerContextCountKey: @(self.layoutContext.pagerInfo.pageCount)
        };
    }
    
    if (self.layoutContext.formInfo) {
        NSMutableDictionary *formInfo = [NSMutableDictionary dictionary];
        [formInfo setValue:self.layoutContext.formInfo.identifier forKey:UAInAppMessageFormContextIDKey];
        [formInfo setValue:@(self.layoutContext.formInfo.submitted) forKey:UAInAppMessageFormContextSubmittedKey];
        [formInfo setValue:self.layoutContext.formInfo.formResponseType forKey:UAInAppMessageFormContextResponseTypeKey];
        [formInfo setValue:self.layoutContext.formInfo.formType forKey:UAInAppMessageFormContextTypeKey];
        context[UAInAppMessageFormContextKey] = formInfo;
    }

    if (self.layoutContext.buttonInfo) {
        context[UAInAppMessageButtonContextKey] = @{
            UAInAppMessageButtonContextIDKey: self.layoutContext.buttonInfo.identifier
        };
    }
    
    if (self.reportingContext.count) {
        [context setValue:self.reportingContext forKey:UAInAppMessageEventReportingContextKey];
    }
    
    if (context.count) {
        [data setValue:context forKey:UAInAppMessageEventContextKey];
    }

    if (self.source == UAInAppMessageSourceAppDefined) {
        [data setValue:UAInAppMessageEventAppDefinedSourceValue forKey:UAInAppMessageEventSourceKey];
    } else {
        [data setValue:UAInAppMessageEventUrbanAirshipSourceValue forKey:UAInAppMessageEventSourceKey];
    }
    
    UAInAppAutomationEvent *analyticsEvent = [[UAInAppAutomationEvent alloc] init];
    analyticsEvent.inAppEventData = data;
    analyticsEvent.inAppEventType = self.eventType;
    [analytics addEvent:analyticsEvent];
}
@end
