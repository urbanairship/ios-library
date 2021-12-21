
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageResolution+Internal.h"

@protocol UAAnalyticsProtocol;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAInAppPagerSummaryIndexKey;
extern NSString *const UAInAppPagerSummaryDurationKey;


/**
 * In App reporting.
 */

NS_SWIFT_NAME(InAppReporting)
@interface UAInAppReporting : NSObject

+ (instancetype)displayEventWithScheduleID:(NSString *)scheduleID
                                   message:(UAInAppMessage *)message;

+ (instancetype)legacyReplacedEventWithScheduleID:(NSString *)scheduleID
                                    replacementID:(NSString *)replacementID;

+ (instancetype)legacyDirectOpenEventWithScheduleID:(NSString *)scheduleID;



+ (instancetype)interruptedEventWithScheduleID:(NSString *)scheduleID
                                        source:(UAInAppMessageSource)source;

+ (instancetype)resolutionEventWithScheduleID:(NSString *)scheduleID
                                      message:(UAInAppMessage *)message
                                   resolution:(UAInAppMessageResolution *)resolution
                                  displayTime:(NSTimeInterval)displayTime;

+ (instancetype)buttonTapEventWithScheduleID:(NSString *)scheduleID
                                     message:(UAInAppMessage *)message
                                    buttonID:(NSString *)buttonID;

+ (instancetype)pageViewEventWithScheduleID:(NSString *)scheduleID
                                    message:(UAInAppMessage *)message
                                    pagerID:(NSString *)pagerID
                                      index:(NSInteger)pageIndex
                                      count:(NSInteger)pageCount
                                  completed:(BOOL)completed;

+ (instancetype)pageSwipeEventWithScheduleID:(NSString *)scheduleID
                                     message:(UAInAppMessage *)message
                                     pagerID:(NSString *)pagerID
                                   fromIndex:(NSInteger)fromIndex
                                     toIndex:(NSInteger)toIndex;

+ (instancetype)pagerCompletedEventWithScheduleID:(NSString *)scheduleID
                                          message:(UAInAppMessage *)message
                                          pagerID:(NSString *)pagerID
                                            index:(NSInteger)pageIndex
                                            count:(NSInteger)pageCount;

+ (instancetype)pagerSummaryEventWithScehduleID:(NSString *)scheduleID
                                        message:(UAInAppMessage *)message
                                        pagerID:(NSString *)pagerID
                                    viewedPages:(NSArray *)viewedPages
                                          count:(NSInteger)pageCount
                                      completed:(BOOL)completed;

+ (instancetype)formDisplayEventWithScheduleID:(NSString *)scheduleID
                                       message:(UAInAppMessage *)message
                                        formID:(NSString *)formID;

+ (instancetype)formResultEventWithScheduleID:(NSString *)scheduleID
                                       message:(UAInAppMessage *)message
                                     formData:(NSDictionary *)formData;


@property(nonatomic, copy, nullable) NSDictionary *campaigns;
@property(nonatomic, copy, nullable) NSDictionary *reportingContext;
@property(nonatomic, copy, nullable) NSDictionary *layoutState;

- (void)record:(id<UAAnalyticsProtocol>)analytics;

@end

NS_ASSUME_NONNULL_END

