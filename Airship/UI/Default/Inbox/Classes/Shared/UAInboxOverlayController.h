//  Based on MTPopupWindow by Marin Todorov
//  http://www.touch-code-magazine.com/showing-a-popup-window-in-ios-class-for-download/

#import <Foundation/Foundation.h>
#import "UAInboxMessage.h"
#import "UABeveledLoadingIndicator.h"

/**
 * This class provides an overlay window that can be popped over
 * the app's UI without totally obscuring it, and that loads a
 * given rich push message in an embedded UIWebView.  It is used
 * in the reference UI implementation for displaying in-app messages
 * without requiring navigation to the inbox.
 */
@interface UAInboxOverlayController : NSObject <UIWebViewDelegate>

{
    
    UIViewController *parentViewController;
    UIView *bgView;
    UIView *bigPanelView;
    UABeveledLoadingIndicator *loadingIndicator;
    UIWebView *webView;
    UAInboxMessage *message;
}

/**
 * The UIWebView used to display the message content.
 */
@property(nonatomic, retain) UIWebView *webView;

/**
 * The UAInboxMessage being displayed.
 */
@property(nonatomic, retain) UAInboxMessage *message;

/**
 * Convenience constructor.
 * @param viewController the view controller to display the overlay in
 * @param messageID the message ID of the rich push message to display
 */
+ (void)showWindowInsideViewController:(UIViewController *)viewController withMessageID:(NSString *)messageId;

/**
 * Initializer, creates an overlay window and loads the given content within a particular view controller.
 * @param viewController the view controller to display the overlay in
 * @param messageID the message ID of the rich push message to display
 */
- (id)initWithParentViewController:(UIViewController *)parent andMessageID:(NSString*)messageID;

@end
