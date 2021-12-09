/* Copyright Airship and Contributors */

#import "UAInAppMessageAirshipLayoutAdapter+Internal.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAInAppMessageAdvancedAdapterProtocol+Internal.h"
#import "UAAutomationNativeBridgeExtension+Internal.h"
#import "UAInAppMessageButtonTapEvent+Internal.h"
#import "UAInAppMessagePageViewEvent+Internal.h"
#import "UAInAppMessagePageSwipeEvent+Internal.h"
#import "UAInAppMessageFormResultEvent+Internal.h"
#import "UAInAppMessageFormDisplayEvent+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@interface UAInAppMessageAirshipLayoutAdapter() <UAThomasDelegate>
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) NSString *messageID;
@property (nonatomic, strong) NSDictionary *campaigns;
@property (nonatomic, strong) UAInAppMessageAirshipLayoutDisplayContent *displayContent;
@property (nonatomic, copy, nullable) UADisposable *(^deferredDisplay)(void);
@property (nonatomic, copy, nullable) void (^onDismiss)(UAInAppMessageResolution *, NSDictionary *);
@property (nonatomic, copy, nullable) void (^onDisplay)(NSDictionary *);
@end

@implementation UAInAppMessageAirshipLayoutAdapter

+ (instancetype)adapterForMessage:(UAInAppMessage *)message {
    return [[self alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
        self.displayContent = (UAInAppMessageAirshipLayoutDisplayContent *)self.message.displayContent;

    }

    return self;
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets
        completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    completionHandler(UAInAppMessagePrepareResultSuccess);
}

- (BOOL)isReadyToDisplay {
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = [[UAInAppMessageSceneManager shared] sceneForMessage:self.message];
        if (!scene) {
            return NO;
        }
        
        UAAutomationNativeBridgeExtension *nativeBridgeExtension = [UAAutomationNativeBridgeExtension extensionWithMessage:self.message];
        
        UAThomasExtensions *extensions = [[UAThomasExtensions alloc] initWithNativeBridgeExtension:nativeBridgeExtension];

        self.deferredDisplay = [UAThomas deferredDisplayWithJson:self.displayContent.layout
                                                           scene:scene
                                                      extensions:extensions
                                                        delegate:self
                                                           error:nil];
        if (!self.deferredDisplay) {
            return NO;
        }
        
        return YES;
    } else {
        return NO;
    }
}


- (void)display:(void (^)(NSDictionary *))onDisplay
      onDismiss:(void (^)(UAInAppMessageResolution *, NSDictionary *))onDismiss
     scheduleID:(nonnull NSString *)scheduleID
      campaigns:(nonnull NSDictionary *)campaigns {
    
    self.onDisplay = onDisplay;
    self.onDismiss = onDismiss;
    self.messageID = scheduleID;
    self.campaigns = campaigns;
    self.deferredDisplay();
}


- (void)onDisplayedWithReportingContext:(NSDictionary<NSString *,id> *)reportingContext {
    if (self.onDisplay != nil) {
        self.onDisplay(reportingContext);
        self.onDisplay = nil;
    }
}

- (void)onDismissedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier
                      buttonDescription:(NSString * _Nonnull)buttonDescription
                                 cancel:(BOOL)cancel
                       reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    
    // Create a button info from callback data
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder *builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder *builder) {
            builder.text = buttonDescription ?: buttonIdentifier;
        }];
        builder.identifier = buttonIdentifier;
        builder.behavior = cancel ? UAInAppMessageButtonInfoBehaviorCancel : UAInAppMessageButtonInfoBehaviorDismiss;
    }];
    
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:buttonInfo];
    [self dimissWithResolution:resolution reportingContext:reportingContext];
}

- (void)onDismissedWithReportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution userDismissedResolution];
    [self dimissWithResolution:resolution reportingContext:reportingContext];
}

- (void)onTimedOutWithReportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution timedOutResolution];
    [self dimissWithResolution:resolution reportingContext:reportingContext];
}

- (void)onButtonTappedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessageButtonTapEvent *event = [UAInAppMessageButtonTapEvent eventWithMessage:self.message messageID:self.messageID buttonIdentifier:buttonIdentifier reportingContext:reportingContext campaigns:self.campaigns];
    [[UAirship analytics] addEvent:event];
}

- (void)onFormDisplayedWithFormIdentifier:(NSString * _Nonnull)formIdentifier reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessageFormDisplayEvent *event = [UAInAppMessageFormDisplayEvent eventWithMessage:self.message messageID:self.messageID formIdentifier:formIdentifier reportingContext:reportingContext campaigns:self.campaigns];
    [[UAirship analytics] addEvent:event];
}

- (void)onFormSubmittedWithFormIdentifier:(NSString * _Nonnull)formIdentifier formData:(NSDictionary<NSString *,id> * _Nonnull)formData reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessageFormResultEvent *event = [UAInAppMessageFormResultEvent eventWithMessage:self.message messageID:self.messageID formIdentifier:formIdentifier formData:formData reportingContext:reportingContext campaigns:self.campaigns];
    [[UAirship analytics] addEvent:event];
}

- (void)onPageViewedWithPagerIdentifier:(NSString * _Nonnull)pagerIdentifier pageIndex:(NSInteger)pageIndex pageCount:(NSInteger)pageCount completed:(BOOL)completed reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessagePageViewEvent *event = [UAInAppMessagePageViewEvent eventWithMessage:self.message messageID:self.messageID pagerIdentifier:pagerIdentifier pageIndex:pageIndex pageCount:pageCount completed:completed reportingContext:reportingContext campaigns:self.campaigns];
    [[UAirship analytics] addEvent:event];
}

- (void)onPageSwipedWithPagerIdentifier:(NSString * _Nonnull)pagerIdentifier fromIndex:(NSInteger)fromIndex toIndex:(NSInteger)toIndex reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    UAInAppMessagePageSwipeEvent *event = [UAInAppMessagePageSwipeEvent eventWithMessage:self.message messageID:self.messageID pagerIdentifier:pagerIdentifier fromIndex:fromIndex toIndex:toIndex reportingContext:reportingContext campaigns:self.campaigns];
    [[UAirship analytics] addEvent:event];
}



- (void)dimissWithResolution:(UAInAppMessageResolution *)resolution
            reportingContext:(NSDictionary *)reportingContext {
    
    if (self.onDismiss != nil) {
        self.onDismiss(resolution, reportingContext);
    }
    
    self.onDismiss = nil;
}

@end

