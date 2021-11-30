/* Copyright Airship and Contributors */

#import "UAInAppMessageAirshipLayoutAdapter+Internal.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"
#import "UAInAppMessageSceneManager.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@interface UAInAppMessageAirshipLayoutAdapter() <UAThomasDelegate>
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageAirshipLayoutDisplayContent *displayContent;
@property (nonatomic, copy, nullable) UADisposable *(^deferredDisplay)(void);
@property (nonatomic, copy, nullable) void (^completionHandler)(UAInAppMessageResolution*);

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
        
        self.deferredDisplay = [UAThomas deferredDisplayWithJson:self.displayContent.layout
                                                           scene:scene
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

- (void)display:(void (^)(UAInAppMessageResolution *))completionHandler {
    self.completionHandler = completionHandler;
    self.deferredDisplay();
}

- (void)onDismissedWithButtonIdentifier:(NSString * _Nullable)buttonIdentifier cancel:(BOOL)cancel reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    if (self.completionHandler != nil) {
        self.completionHandler([UAInAppMessageResolution userDismissedResolution]);
        self.completionHandler = nil;
    }
}


- (void)onTimedOutWithReportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    if (self.completionHandler != nil) {
        self.completionHandler([UAInAppMessageResolution timedOutResolution]);
        self.completionHandler = nil;
    }
}



- (void)onButtonTappedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    
}


- (void)onFormDisplayedWithFormIdentifier:(NSString * _Nonnull)formIdentifier reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    
}

- (void)onFormSubmittedWithFormIdentifier:(NSString * _Nonnull)formIdentifier formData:(NSDictionary<NSString *,id> * _Nonnull)formData reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    
}

- (void)onPageViewedWithPagerIdentifier:(NSString * _Nonnull)pagerIdentifier pageIndex:(NSInteger)pageIndex pageCount:(NSInteger)pageCount completed:(BOOL)completed reportingContext:(NSDictionary<NSString *,id> * _Nonnull)reportingContext {
    
}
@end

