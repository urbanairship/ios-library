/* Copyright 2017 Urban Airship and Contributors */

#import "UAInAppMessageHTMLAdapter.h"
#import "UAInAppMessageAdapterProtocol.h"
#import "UAInAppMessageHTMLController+Internal.h"
#import "UAInAppMessageHTMLDisplayContent.h"
#import "UAUtils.h"
#import "UAirship.h"

NS_ASSUME_NONNULL_BEGIN

@interface UAInAppMessageHTMLAdapter ()
@property(nonatomic, strong) UAInAppMessageHTMLController *htmlController;
@property(nonatomic, strong) UAInAppMessage *message;
@end

@implementation UAInAppMessageHTMLAdapter

+ (nonnull instancetype)adapterForMessage:(nonnull UAInAppMessage *)message {
    return [[self alloc] initWithMessage:message];
}

- (instancetype)initWithMessage:(UAInAppMessage *)message {
    self = [super init];

    if (self) {
        self.message = message;
    }

    return self;
}

- (BOOL)isNetworkConnected {
    return ![[UAUtils connectionType] isEqualToString:kUAConnectionTypeNone];
}

- (void)prepare:(nonnull void (^)(UAInAppMessagePrepareResult))completionHandler {
    UAInAppMessageHTMLDisplayContent *content = (UAInAppMessageHTMLDisplayContent *)self.message.displayContent;
    BOOL whitelisted = [[UAirship shared].whitelist isWhitelisted:[NSURL URLWithString:content.url]];
    if (!whitelisted) {
        UA_LERR(@"HTML in-app message URL is not whitelisted. Unable to display message.");
        return completionHandler(UAInAppMessagePrepareResultCancel);
    }

    completionHandler([self isNetworkConnected] ? UAInAppMessagePrepareResultSuccess : UAInAppMessagePrepareResultRetry);
}

- (BOOL)isReadyToDisplay {
    return [self isNetworkConnected];
}

- (void)display:(nonnull void (^)(UAInAppMessageResolution * _Nonnull))completionHandler {
    UAInAppMessageHTMLDisplayContent *displayContent = (UAInAppMessageHTMLDisplayContent *)self.message.displayContent;

    self.htmlController = [UAInAppMessageHTMLController htmlControllerWithHTMLMessageID:self.message.identifier
                                                                         displayContent:displayContent];
    [self.htmlController showWithParentView:[UAUtils mainWindow]
                          completionHandler:completionHandler];
}

@end

NS_ASSUME_NONNULL_END
