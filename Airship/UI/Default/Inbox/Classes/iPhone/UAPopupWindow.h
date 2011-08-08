//  Based on MTPopupWindow by Marin Todorov
//  http://www.touch-code-magazine.com/showing-a-popup-window-in-ios-class-for-download/

#import <Foundation/Foundation.h>
#import "UAInboxMessage.h"

@interface UAPopupWindow : NSObject <UIWebViewDelegate>

{
    UIView *bgView;
    UIView *bigPanelView;
    UIWebView *webView;
    UAInboxMessage *message;
}

@property(nonatomic, retain) UIWebView *webView;
@property(nonatomic, retain) UAInboxMessage *message;

+ (void)showWindowInsideView:(UIView *)view withMessageID:(NSString *)messageId;
+ (void)showWindowWithMessageID:(NSString *)messageId;

@end
