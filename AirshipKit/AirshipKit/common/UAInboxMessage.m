/* Copyright 2017 Urban Airship and Contributors */

#import "UAInboxMessage+Internal.h"
#import "UAInbox.h"
#import "UAInboxMessageData+Internal.h"
#import "UAInboxAPIClient+Internal.h"
#import "UAInboxMessageList+Internal.h"
#import "UAUtils.h"

@implementation UAInboxMessage

- (instancetype)initWithMessageData:(UAInboxMessageData *)data {
    self = [super init];
    if (self) {
        self.data = data;
    }
    return self;
}

+ (instancetype)messageWithData:(UAInboxMessageData *)data {
    return [[self alloc] initWithMessageData:data];
}

#pragma mark -
#pragma mark NSObject methods

// NSObject override
- (NSString *)description {
    return [NSString stringWithFormat: @"%@ - %@", self.messageID, self.title];
}

#pragma mark -
#pragma mark Mark As Read Delegate Methods


- (UADisposable *)markMessageReadWithCompletionHandler:(UAInboxMessageCallbackBlock)completionHandler {
    if (!self.unread) {
        return nil;
    }

    return [self.inbox markMessagesRead:@[self] completionHandler:^{
        if (completionHandler) {
            completionHandler(self);
        }
    }];
}

- (BOOL)isExpired {
    if (self.messageExpiration) {
        NSComparisonResult result = [self.messageExpiration compare:[NSDate date]];
        return (result == NSOrderedAscending || result == NSOrderedSame);
    }

    return NO;
}

- (NSString *)messageID {
    return self.data.messageID;
}

- (NSURL *)messageBodyURL {
    return self.data.messageBodyURL;
}

- (NSURL *)messageURL {
    return self.data.messageURL;
}

- (NSString *)contentType {
    return self.data.contentType;
}

- (BOOL)unread {
    return self.data.unreadClient && self.data.unread;
}

- (NSDate *)messageSent {
    return self.data.messageSent;
}

- (NSDate *)messageExpiration {
    return self.data.messageExpiration;
}

- (NSString *)title {
    return self.data.title;
}

- (NSDictionary *)extra {
    return self.data.extra;
}

- (NSDictionary *)rawMessageObject {
    return self.data.rawMessageObject;
}

#pragma mark -
#pragma mark Quick Look methods

- (BOOL)waitWithTimeoutInterval:(NSTimeInterval)interval pollingWebView:(UIWebView *)webView {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:interval];
    // The webView may not have begun loading at this point
    BOOL loadingStarted = webView.loading;
    while ([timeoutDate timeIntervalSinceNow] > 0) {
        if (!loadingStarted && webView.loading) {
            loadingStarted = YES;
        } else if (loadingStarted && !webView.loading) {
            // Break once the webView has transitioned from a loading to non-loading state
            break;
        }
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }

    return [timeoutDate timeIntervalSinceNow] > 0;
}

- (id)debugQuickLookObject {

    UIWebView *webView = [[UIWebView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.messageBodyURL];
    NSString *auth = [UAUtils userAuthHeaderString];
    [request setValue:auth forHTTPHeaderField:@"Authorization"];

    // Load the message body, spin the run loop and poll the webView with a 5 second timeout.
    [webView loadRequest:request];
    [self waitWithTimeoutInterval:5 pollingWebView:webView];

    // Return a UIImage rendered from the webView
    UIGraphicsBeginImageContext(webView.bounds.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [webView.layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
