//  Based on MTPopupWindow by Marin Todorov
//  http://www.touch-code-magazine.com/showing-a-popup-window-in-ios-class-for-download/

#import <Foundation/Foundation.h>
#import "UAInboxMessage.h"

@interface UAInboxOverlayController : NSObject <UIWebViewDelegate>

{
    
    UIViewController *parentViewController;
    UIView *bgView;
    UIView *bigPanelView;
    UIWebView *webView;
    UAInboxMessage *message;
}

@property(nonatomic, retain) UIWebView *webView;
@property(nonatomic, retain) UAInboxMessage *message;

+ (void)showWindowInsideViewController:(UIViewController *)viewController withMessageID:(NSString *)messageId;

@end
