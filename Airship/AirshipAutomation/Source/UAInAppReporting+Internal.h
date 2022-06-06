
#import "UAInAppMessage+Internal.h"
#import "UAInAppMessageResolution+Internal.h"

@protocol UAAnalyticsProtocol;
@class UAThomasLayoutContext;
@class UAThomasPagerInfo;
@class UAThomasFormInfo;
@class UAThomasFormResult;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAInAppPagerSummaryIndexKey;
extern NSString *const UAInAppPagerSummaryDurationKey;
extern NSString *const UAInAppPagerSummaryIDKey;


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
                                  pagerInfo:(UAThomasPagerInfo *)pagerInfo
                                  viewCount:(NSUInteger)viewCount;

+ (instancetype)pageSwipeEventWithScheduleID:(NSString *)scheduleID
                                     message:(UAInAppMessage *)message
                                        from:(UAThomasPagerInfo *)from
                                          to:(UAThomasPagerInfo *)to;
                                    

+ (instancetype)pagerCompletedEventWithScheduleID:(NSString *)scheduleID
                                          message:(UAInAppMessage *)message
                                        pagerInfo:(UAThomasPagerInfo *)pagerInfo;

+ (instancetype)pagerSummaryEventWithScehduleID:(NSString *)scheduleID
                                        message:(UAInAppMessage *)message
                                      pagerInfo:(UAThomasPagerInfo *)pagerInfo
                                    viewedPages:(NSArray *)viewedPages;
                                    
+ (instancetype)formDisplayEventWithScheduleID:(NSString *)scheduleID
                                       message:(UAInAppMessage *)message
                                      formInfo:(UAThomasFormInfo *)formInfo;

+ (instancetype)formResultEventWithScheduleID:(NSString *)scheduleID
                                       message:(UAInAppMessage *)message
                                       formResult:(UAThomasFormResult *)formResult;

+ (instancetype)permissionResultEventWithScheduleID:(NSString *)scheduleID
                                            message:(UAInAppMessage *)message
                                         permission:(NSString *)permission
                                     startingStatus:(NSString *)startingStatus
                                       endingStatus:(NSString *)endingStatus;

@property(nonatomic, copy, nullable) NSDictionary *campaigns;
@property(nonatomic, copy, nullable) NSDictionary *reportingContext;
@property(nonatomic, strong, nullable) UAThomasLayoutContext *layoutContext;

- (void)record:(id<UAAnalyticsProtocol>)analytics;

@end

NS_ASSUME_NONNULL_END

