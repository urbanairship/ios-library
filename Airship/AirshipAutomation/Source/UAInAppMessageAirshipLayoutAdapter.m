/* Copyright Airship and Contributors */

#import "UAInAppMessageAirshipLayoutAdapter+Internal.h"
#import "UAInAppMessageAirshipLayoutDisplayContent+Internal.h"
#import "UAInAppMessageSceneManager.h"
#import "UAInAppMessageAdvancedAdapterProtocol+Internal.h"
#import "UAAutomationNativeBridgeExtension+Internal.h"
#import "UAInAppReporting+Internal.h"

#if __has_include("AirshipKit/AirshipKit-Swift.h")
#import <AirshipKit/AirshipKit-Swift.h>
#elif __has_include("AirshipKit-Swift.h")
#import "AirshipKit-Swift.h"
#else
@import AirshipCore;
#endif

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
@property (nonatomic, copy, nullable) void (^onDismiss)(UAInAppMessageResolution *, NSDictionary *);
@property (nonatomic, copy, nullable) void (^onEvent)(UAInAppReporting *);
@property (nonatomic, strong) NSMutableSet *viewedPages;
@property (nonatomic, strong) NSArray *urlInfos;
@property (nonatomic, strong) UAInAppMessageAssets *assets;
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
        self.viewedPages = [NSMutableSet set];
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
                    onDismiss:(void (^)(UAInAppMessageResolution *, NSDictionary *))onDismiss {

    
    self.onDismiss = onDismiss;
    self.onEvent = onEvent;
    self.scheduleID = scheduleID;
    self.deferredDisplay();
}

- (void)onDismissedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier
                      buttonDescription:(NSString * _Nonnull)buttonDescription
                                 cancel:(BOOL)cancel
                            layoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    
    
    // Create a button info from callback data
    UAInAppMessageButtonInfo *buttonInfo = [UAInAppMessageButtonInfo buttonInfoWithBuilderBlock:^(UAInAppMessageButtonInfoBuilder *builder) {
        builder.label = [UAInAppMessageTextInfo textInfoWithBuilderBlock:^(UAInAppMessageTextInfoBuilder *builder) {
            builder.text = buttonDescription ?: buttonIdentifier;
        }];
        builder.identifier = buttonIdentifier;
        builder.behavior = cancel ? UAInAppMessageButtonInfoBehaviorCancel : UAInAppMessageButtonInfoBehaviorDismiss;
    }];
    
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution buttonClickResolutionWithButtonInfo:buttonInfo];
    [self dimissWithResolution:resolution layoutState:layoutState];
}

- (void)onDismissedWithLayoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution userDismissedResolution];
    [self dimissWithResolution:resolution layoutState:layoutState];
}

- (void)onTimedOutWithLayoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    UAInAppMessageResolution *resolution = [UAInAppMessageResolution timedOutResolution];
    [self dimissWithResolution:resolution layoutState:layoutState];
}

- (void)onButtonTappedWithButtonIdentifier:(NSString * _Nonnull)buttonIdentifier layoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    
    UAInAppReporting *reporting = [UAInAppReporting buttonTapEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                        buttonID:buttonIdentifier];
    reporting.layoutState = layoutState;
    
    [self record:reporting];
}

- (void)onFormDisplayedWithFormIdentifier:(NSString * _Nonnull)formIdentifier
                              layoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    
    UAInAppReporting *reporting = [UAInAppReporting formDisplayEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                        formID:formIdentifier];
    reporting.layoutState = layoutState;

    [self record:reporting];
}

- (void)onFormSubmittedWithFormIdentifier:(NSString * _Nonnull)formIdentifier
                                 formData:(NSDictionary<NSString *,id> * _Nonnull)formData
                              layoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    
    UAInAppReporting *reporting = [UAInAppReporting formResultEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                         formData:formData];
    reporting.layoutState = layoutState;
    [self record:reporting];
}

- (void)onPageViewedWithPagerIdentifier:(NSString * _Nonnull)pagerIdentifier
                              pageIndex:(NSInteger)pageIndex
                              pageCount:(NSInteger)pageCount
                              completed:(BOOL)completed
                            layoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    
    // Only send one page event per pager index
    NSString *pageKey = [NSString stringWithFormat:@"%@%ld", pagerIdentifier, pageIndex];
    if ([self.viewedPages containsObject:pageKey]) {
        return;
    }
    [self.viewedPages addObject:pageKey];
    
    UAInAppReporting *reporting = [UAInAppReporting pageViewEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                         pagerID:pagerIdentifier
                                                                          index:pageIndex
                                                                          count:pageCount
                                                                      completed:completed];
    reporting.layoutState = layoutState;
    [self record:reporting];
}

- (void)onPageSwipedWithPagerIdentifier:(NSString * _Nonnull)pagerIdentifier
                              fromIndex:(NSInteger)fromIndex
                                toIndex:(NSInteger)toIndex
                            layoutState:(NSDictionary<NSString *,id> * _Nonnull)layoutState {
    
    UAInAppReporting *reporting = [UAInAppReporting pageSwipeEventWithScheduleID:self.scheduleID
                                                                         message:self.message
                                                                         pagerID:pagerIdentifier
                                                                       fromIndex:fromIndex
                                                                         toIndex:toIndex];
    reporting.layoutState = layoutState;
    [self record:reporting];
}

- (void)dimissWithResolution:(UAInAppMessageResolution *)resolution layoutState:(NSDictionary *)layoutState {
    if (self.onDismiss != nil) {
        self.onDismiss(resolution, layoutState);
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
