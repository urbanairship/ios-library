/* Copyright Airship and Contributors */

#import "UAInAppMessageAirshipLayoutAdapter+Internal.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAInAppMessageAdvancedAdapterProtocol+Internal.h"
#import "UAAutomationNativeBridgeExtension+Internal.h"
#import "UAInAppReporting+Internal.h"
#import "UAActiveTimer+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

@interface UAPagerSummary : NSObject
@property (nonatomic, strong) NSMutableArray *viewedPages;
@property (nonatomic, strong) UAActiveTimer *timer;
@property (nonatomic, strong) UAThomasPagerInfo *pagerInfo;

@end

@implementation UAPagerSummary
- (instancetype)init{
    self = [super init];
    if (self) {
        self.viewedPages = [NSMutableArray array];
    }
    return self;
}

- (void)pageFinished {
    if (self.pagerInfo != nil) {
        [self.timer stop];
        NSDictionary *viewedPage = @{
            UAInAppPagerSummaryIndexKey: @(self.pagerInfo.pageIndex),
            UAInAppPagerSummaryDurationKey: [NSString stringWithFormat:@"%.3f", self.timer.time],
            UAInAppPagerSummaryIDKey: self.pagerInfo.pageIdentifier
        };
        [self.viewedPages addObject:viewedPage];
    }
}

- (void)setPagerInfo:(UAThomasPagerInfo *)pagerInfo {
    [self pageFinished];
    _pagerInfo = pagerInfo;
    self.timer = [[UAActiveTimer alloc] init];
    [self.timer start];
}

@end

@interface UAAssetImageProvider : NSObject<UAImageProvider>
@property (nonatomic, strong) UAInAppMessageAssets *assets;
@end

@implementation UAAssetImageProvider
- (UIImage * _Nullable)getWithUrl:(NSURL * _Nonnull)url {
    if ([self.assets isCached:url]) {
        NSURL *cacheURL = [self.assets getCacheURL:url];
        NSData *data =  [[NSFileManager defaultManager] contentsAtPath:[cacheURL path]];
        return [UIImage fancyImageWithData:data fillIn:NO];
    }
    return nil;
}

@end


@interface UAInAppMessageAirshipLayoutAdapter() <UAThomasDelegate>
@property (nonatomic, strong) UAInAppMessage *message;
@property (nonatomic, strong) UAInAppMessageAirshipLayoutDisplayContent *displayContent;
@property (nonatomic, copy, nullable) UADisposable *(^deferredDisplay)(void);
@property (nullable, nonatomic, strong) NSString *scheduleID;
@property (nonatomic, copy, nullable) void (^onDismiss)(UAInAppMessageResolution *);
@property (nonatomic, copy, nullable) void (^onEvent)(UAInAppReporting *);
@property (nonatomic, strong) NSMutableDictionary<NSString *, UAPagerSummary *> *pagerSummaries;
@property (nonatomic, strong) NSMutableSet<NSString *> *completedPagers;
@property (nonatomic, strong) NSArray *urlInfos;
@property (nonatomic, strong) UAInAppMessageAssets *assets;
@property (nonatomic, strong) UAActiveTimer *displayTimer;
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
        self.pagerSummaries = [NSMutableDictionary dictionary];
        self.completedPagers = [NSMutableSet set];
        self.urlInfos = [UAThomas urlsWithJson:self.displayContent.layout error:nil];
    }

    return self;
}

- (void)prepareWithAssets:(nonnull UAInAppMessageAssets *)assets
        completionHandler:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    
    for (UAURLInfo *info in self.urlInfos) {
        NSURL *url = [NSURL URLWithString:info.url];
        if (![[UAirship shared].URLAllowList isAllowed:url scope:UAURLAllowListScopeOpenURL]) {
            UA_LERR(@"In-app message URL %@ is not allowed. Unable to display message.", url);
            return completionHandler(UAInAppMessagePrepareResultCancel);
        }
    }
    
    self.assets = assets;
    completionHandler(UAInAppMessagePrepareResultSuccess);
}

- (BOOL)isReadyToDisplay {
    if (@available(iOS 13.0, *)) {
        
        BOOL isConnected = [self isNetworkConnected];
        
        for (UAURLInfo *info in self.urlInfos) {
            if (info.urlType == UrlTypesImage && ![self.assets isCached:[NSURL URLWithString:info.url]]) {
                continue;
            }
            
            if (!isConnected) {
                return false;
            }
        }
        
        UIWindowScene *scene = [[UAInAppMessageSceneManager shared] sceneForMessage:self.message];
        if (!scene) {
            return NO;
        }
        
        UAAutomationNativeBridgeExtension *nativeBridgeExtension = [UAAutomationNativeBridgeExtension extensionWithMessage:self.message];
        
        UAAssetImageProvider *assetImageProvider = [[UAAssetImageProvider alloc] init];
        assetImageProvider.assets = self.assets;

        UAThomasExtensions *extensions = [[UAThomasExtensions alloc]
                                          initWithNativeBridgeExtension:nativeBridgeExtension
                                          imageProvider:assetImageProvider];

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


- (void)displayWithScheduleID:(nonnull NSString *)scheduleID
                      onEvent:(void (^)(UAInAppReporting *))onEvent
                    onDismiss:(void (^)(UAInAppMessageResolution *))onDismiss {
    self.onDismiss = onDismiss;
    self.onEvent = onEvent;
    self.scheduleID = scheduleID;
    
    self.displayTimer = [[UAActiveTimer alloc] init];
    [self.displayTimer start];
    
    // Display event
    UAInAppReporting *display = [UAInAppReporting displayEventWithScheduleID:scheduleID message:self.message];
    [self record:display];
    self.deferredDisplay();
}

- (void)onDismissedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier
                      buttonDescription:(NSString * _Nonnull)buttonDescription
                                 cancel:(BOOL)cancel
                          layoutContext:(UAThomasLayoutContext * _Nonnull)layoutContext {
    
    // Create a button info from callback data
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder *builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder *builder) {
            builder.text = buttonDescription;
        }];
        builder.identifier = buttonIdentifier;
        builder.behavior = cancel ? UAInAppMessageButtonInfoBehaviorCancel : UAInAppMessageButtonInfoBehaviorDismiss;
    }];
    
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:buttonInfo];
    [self dimissWithResolution:resolution layoutContext:layoutContext];
}

-(void)onDismissedWithLayoutContext:(UAThomasLayoutContext * _Nullable)layoutContext {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution userDismissedResolution];
    [self dimissWithResolution:resolution layoutContext:layoutContext];
}

- (void)onTimedOutWithLayoutContext:(UAThomasLayoutContext * _Nullable)layoutContext {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution timedOutResolution];
    [self dimissWithResolution:resolution layoutContext:layoutContext];
}

- (void)onRunActionsWithActions:(NSDictionary<NSString *,id> *)actions
                  layoutContext:(UAThomasLayoutContext *)layoutContext {

    // Capturing all the data we need to generate the event since the action block
    // will be potentially long lived
    void (^onEvent)(UAInAppReporting *) = self.onEvent;
    id message = self.message;
    id scheduleID = self.scheduleID;

    void (^permissionResultReceiver)(UAPermission, UAPermissionStatus, UAPermissionStatus) = ^(UAPermission permission, UAPermissionStatus start, UAPermissionStatus end) {

        // We cant expose swift types in an obj-c interface so we stringify it before passing it over. We can
        // do it the right way once we convert this module to swift.
        id permissionString = [UAUtils permissionString:permission];
        id startinStatuString = [UAUtils permissionStatusString:start];
        id endingStatusString = [UAUtils permissionStatusString:end];

        UAInAppReporting *event = [UAInAppReporting permissionResultEventWithScheduleID:scheduleID
                                                                                message:message
                                                                             permission:permissionString
                                                                         startingStatus:startinStatuString
                                                                           endingStatus:endingStatusString];

        event.layoutContext = layoutContext;

        if (onEvent) {
            onEvent(event);
        }
    };

    id metaData = @{ UAPromptPermissionAction.resultReceiverMetadataKey: permissionResultReceiver };

    [UAActionRunner runActionsWithActionValues:actions
                                     situation:UASituationManualInvocation
                                      metadata:metaData
                             completionHandler:^(UAActionResult *result) {
        UA_LDEBUG(@"Finished running actions.");
    }];

}
- (void)onButtonTappedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier
                             layoutContext:(UAThomasLayoutContext * _Nonnull)layoutContext {

    UAInAppReporting *reporting = [UAInAppReporting buttonTapEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                        buttonID:buttonIdentifier];
    reporting.layoutContext = layoutContext;
    
    [self record:reporting];
}


- (void)onFormDisplayedWithFormInfo:(UAThomasFormInfo * _Nonnull)formInfo
                      layoutContext:(UAThomasLayoutContext * _Nonnull)layoutContext {

    UAInAppReporting *reporting = [UAInAppReporting formDisplayEventWithScheduleID:self.scheduleID
                                                                           message:self.message
                                                                            formInfo:formInfo];
    reporting.layoutContext = layoutContext;

    [self record:reporting];
}

- (void)onFormSubmittedWithFormResult:(UAThomasFormResult * _Nonnull)formResult
                        layoutContext:(UAThomasLayoutContext * _Nonnull)layoutContext {
    
    UAInAppReporting *reporting = [UAInAppReporting formResultEventWithScheduleID:self.scheduleID
                                                                          message:self.message
                                                                       formResult:formResult];
    reporting.layoutContext = layoutContext;
    [self record:reporting];
}

- (void)onPageViewedWithPagerInfo:(UAThomasPagerInfo * _Nonnull)pagerInfo
                    layoutContext:(UAThomasLayoutContext * _Nonnull)layoutContext {

    // Update summary
    UAPagerSummary *summary = self.pagerSummaries[pagerInfo.identifier];
    if (!summary) {
        summary = [[UAPagerSummary alloc] init];
        self.pagerSummaries[pagerInfo.identifier] = summary;
    }
    summary.pagerInfo = pagerInfo;
    
    NSUInteger viewCount = 1;
    for (NSDictionary *viewedPage in summary.viewedPages) {
        if ([pagerInfo.pageIdentifier isEqualToString:viewedPage[UAInAppPagerSummaryIDKey]]) {
            viewCount++;
        }
    }
    
    // Page view
    UAInAppReporting *pageView = [UAInAppReporting pageViewEventWithScheduleID:self.scheduleID
                                                                       message:self.message
                                                                     pagerInfo:pagerInfo
                                                                     viewCount:viewCount];
    pageView.layoutContext = layoutContext;
    [self record:pageView];
    
    // Only send 1 completed per pager
    if (pagerInfo.completed && ![self.completedPagers containsObject:pagerInfo.identifier]) {
        [self.completedPagers addObject:pagerInfo.identifier];
        UAInAppReporting *completed = [UAInAppReporting pagerCompletedEventWithScheduleID:self.scheduleID
                                                                                  message:self.message
                                                                                pagerInfo:pagerInfo];
        completed.layoutContext = layoutContext;
        [self record:completed];
    }
  
    
}

- (void)onPageSwipedFrom:(UAThomasPagerInfo * _Nonnull)from
                      to:(UAThomasPagerInfo * _Nonnull)to
           layoutContext:(UAThomasLayoutContext * _Nonnull)layoutContext {

    UAInAppReporting *reporting = [UAInAppReporting pageSwipeEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                            from:from
                                                                              to:to];
    reporting.layoutContext = layoutContext;
    [self record:reporting];
}

- (void)dimissWithResolution:(UAInAppMessageResolution *)resolution
               layoutContext:(UAThomasLayoutContext * _Nullable)layoutContext {
    if (self.onDismiss != nil) {
        
        // Summary events
        for (NSString *pagerID in self.pagerSummaries) {
            UAPagerSummary *summary = self.pagerSummaries[pagerID];
            [summary pageFinished];
            
            if (summary.pagerInfo) {
                UAInAppReporting *reporting = [UAInAppReporting pagerSummaryEventWithScehduleID:self.scheduleID
                                                                                        message:self.message
                                                                                      pagerInfo:summary.pagerInfo
                                                                                    viewedPages:summary.viewedPages];

                reporting.layoutContext = layoutContext;
                [self record:reporting];
            }
        }
        
        
        [self.displayTimer stop];
        
        UAInAppReporting *resolutionEvent = [UAInAppReporting resolutionEventWithScheduleID:self.scheduleID
                                                                                    message:self.message
                                                                                 resolution:resolution
                                                                                displayTime:self.displayTimer.time];
        resolutionEvent.layoutContext = layoutContext;
        [self record:resolutionEvent];
        self.onDismiss(resolution);
    }
    
    self.onDismiss = nil;
}

- (void)record:(UAInAppReporting *)reporting {
    if (self.onEvent) {
        self.onEvent(reporting);
    }
}

- (BOOL)isNetworkConnected {
    return ![[UAUtils connectionType] isEqualToString:UAConnectionType.none];
}

@end


