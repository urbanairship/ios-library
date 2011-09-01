//  Based on MTPopupWindow by Marin Todorov
//  http://www.touch-code-magazine.com/showing-a-popup-window-in-ios-class-for-download/

#import "UAInboxOverlayController.h"
#import "UAInboxMessage.h"
#import "UAInboxMessageList.h"
#import "UAInbox.h"
#import "UAInboxUI.h"
#import "UAUtils.h"

#import <QuartzCore/QuartzCore.h>

#define kShadeViewTag 1000

@interface UAInboxOverlayController(Private)

- (id)initWithParentViewController:(UIViewController *)parent andMessageID:(NSString*)messageID;
- (void)loadMessageAtIndex:(int)index;
- (void)loadMessageForID:(NSString *)mid;

@end

@implementation UAInboxOverlayController

@synthesize webView, message;

/**
 * Opens a popup window and loads the given content within a particular view
 * @param NSString* fileName provide a file name to load a file from the app resources, or a URL to load a web page 
 * @param UIView* view provide a UIViewController's view here (or other view)
 */

+ (void)showWindowInsideViewController:(UIViewController *)viewController withMessageID:(NSString *)messageID {
    [[UAInboxOverlayController alloc] initWithParentViewController:viewController andMessageID:messageID];
}


/**
 * Initializes the class instance, gets a view where the window will pop up in
 * and a file name/ URL
 */
- (id)initWithParentViewController:(UIViewController *)parent andMessageID:(NSString*)messageID {
    self = [super init];
    if (self) {
        // Initialization code here.
        
        parentViewController = [parent retain];
        UIView *sview = parent.view;
        
        bgView = [[[UIView alloc] initWithFrame: sview.bounds] autorelease];
        bgView.autoresizesSubviews = YES;
        bgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [sview addSubview: bgView];
        
        //set the frame later
        webView = [[UIWebView alloc] initWithFrame:CGRectZero];
        webView.backgroundColor = [UIColor clearColor];
        webView.opaque = NO;
        webView.delegate = self;
        
        //hack to hide the ugly webview gradient
        for (UIView* subView in [webView subviews]) {
            if ([subView isKindOfClass:[UIScrollView class]]) {
                for (UIView* shadowView in [subView subviews]) {
                    if ([shadowView isKindOfClass:[UIImageView class]]) {
                        [shadowView setHidden:YES];
                    }
                }
            }
        }
        
        [self loadMessageForID:messageID];
        
        //required to receive orientation updates from NSNotifcationCenter
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(orientationChanged:) 
                                                     name:UIDeviceOrientationDidChangeNotification object:nil];
        
    }
    
    return self;
}    

- (void)loadMessageAtIndex:(int)index {
    self.message = [[UAInbox shared].messageList messageAtIndex:index];
    if (self.message == nil) {
        UALOG(@"Can not find message with index: %d", index);
        return;
    }
    
    NSMutableURLRequest *requestObj = [NSMutableURLRequest requestWithURL: message.messageBodyURL];
    NSString *auth = [UAUtils userAuthHeaderString];
    
    [requestObj setValue:auth forHTTPHeaderField:@"Authorization"];
    [requestObj setTimeoutInterval:5];
    
    [webView stopLoading];
    [webView loadRequest:requestObj];
}

- (void)loadMessageForID:(NSString *)mid {
    UAInboxMessage *msg = [[UAInbox shared].messageList messageForID:mid];
    if (msg == nil) {
        UALOG(@"Can not find message with ID: %@", mid);
        return;
    }
    
    [self loadMessageAtIndex:[[UAInbox shared].messageList indexOfMessage:msg]];
}

/**
 * Afrer the window background is added to the UI the window can animate in
 * and load the UIWebView
 */
-(void)doTransition {
    //faux view
    UIView* fauxView = [[[UIView alloc] initWithFrame: bgView.bounds] autorelease];
    fauxView.autoresizesSubviews = YES;
    fauxView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [bgView addSubview: fauxView];
    
    //the new panel
    bigPanelView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, bgView.frame.size.width, bgView.frame.size.height)] autorelease];
    bigPanelView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bigPanelView.autoresizesSubviews = YES;
    bigPanelView.center = CGPointMake( bgView.frame.size.width/2, bgView.frame.size.height/2);
    
    //add the window background
    UIView *background = [[[UIView alloc] initWithFrame:CGRectInset
                           (bigPanelView.bounds, 15, 30)] autorelease];
    background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    background.backgroundColor = [UIColor whiteColor];
    background.layer.borderColor = [[UIColor blackColor] CGColor];
    background.layer.borderWidth = 2;
    background.center = CGPointMake(bigPanelView.frame.size.width/2, bigPanelView.frame.size.height/2);
    [bigPanelView addSubview: background];
    
    //add the web view
    int webOffset = 2;
    webView.frame = CGRectInset(background.frame, webOffset, webOffset);
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [bigPanelView addSubview: webView];
    
    //add the close button
    int closeBtnOffset = 10;
    UIImage* closeBtnImg = [UIImage imageNamed:@"overlayCloseBtn.png"];
    UIButton* closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    closeBtn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [closeBtn setImage:closeBtnImg forState:UIControlStateNormal];
    [closeBtn setFrame:CGRectMake( background.frame.origin.x + background.frame.size.width - closeBtnImg.size.width - closeBtnOffset, 
                                  background.frame.origin.y ,
                                  closeBtnImg.size.width + closeBtnOffset, 
                                  closeBtnImg.size.height + closeBtnOffset)];
    [closeBtn addTarget:self action:@selector(closePopupWindow) forControlEvents:UIControlEventTouchUpInside];
    [bigPanelView addSubview: closeBtn];
    
    //animation options
    UIViewAnimationOptions options = UIViewAnimationOptionTransitionFlipFromRight |
    UIViewAnimationOptionAllowUserInteraction    |
    UIViewAnimationOptionBeginFromCurrentState;
    
    //run the animation
    [UIView transitionFromView:fauxView toView:bigPanelView duration:0.5 options:options completion: ^(BOOL finished) {
        
        //dim the contents behind the popup window
        UIView* shadeView = [[[UIView alloc] initWithFrame:bigPanelView.frame] autorelease];
        shadeView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        shadeView.backgroundColor = [UIColor blackColor];
        shadeView.alpha = 0.3;
        shadeView.tag = kShadeViewTag;
        [bigPanelView addSubview: shadeView];
        [bigPanelView sendSubviewToBack: shadeView];
    }];
}


#pragma mark UIWebViewDelegate

- (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSURL *url = [request URL];
    
    /*
     ua://callbackArguments:withOptions:/[<arguments>][?<dictionary>]
     */
    
    if ([[url scheme] isEqualToString:@"ua"]) {
        if ((navigationType == UIWebViewNavigationTypeLinkClicked) || (navigationType == UIWebViewNavigationTypeOther)) {
            [UAInboxMessage performJSDelegate:wv url:url];
            return NO;
        }
    }
    
    // send iTunes/Phobos urls to AppStore.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             (([[url host] isEqualToString:@"phobos.apple.com"]) ||
              ([[url host] isEqualToString:@"itunes.apple.com"]))) {
                 
                 // TODO: set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
                 
                 return ![[UIApplication sharedApplication] openURL:url];
             }
    
    // send maps.google.com url or maps: to GoogleMaps.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             (([[url host] isEqualToString:@"maps.google.com"]) ||
              ([[url scheme] isEqualToString:@"maps"]))) {
                 
                 /* Do any special formatting here, for example:
                  
                  NSString *title = @"title";
                  float latitude = 35.4634;
                  float longitude = 9.43425;
                  int zoom = 13;
                  NSString *stringURL = [NSString stringWithFormat:@"http://maps.google.com/maps?q=%@@%1.6f,%1.6f&z=%d", title, latitude, longitude, zoom];
                  
                  */
                 
                 return ![[UIApplication sharedApplication] openURL:url];
             }
    
    // send www.youtube.com url to YouTube.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) &&
             ([[url host] isEqualToString:@"www.youtube.com"])) {
        return ![[UIApplication sharedApplication] openURL:url];
    }
    
    // send mailto: to Mail.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"mailto"])) {
        
        /* Do any special formatting here if you like, for example:
         
         NSString *subject = @"Message subject";
         NSString *body = @"Message body";
         NSString *address = @"address@domain.com";
         NSString *cc = @"address@domain.com";
         NSString *path = [NSString stringWithFormat:@"mailto:%@?cc=%@&subject=%@&body=%@", address, cc, subject, body];
         NSURL *url = [NSURL URLWithString:[path stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
         
         For complex body text you may want to use CFURLCreateStringByAddingPercentEscapes.
         
         */
        
        return ![[UIApplication sharedApplication] openURL:url];
    }
    
    // send tel: to Phone.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"tel"])) {
        
        // TODO: Phone number must not contain spaces or brackets. Spaces or plus signs OK. Can add come checks here.
        
        return ![[UIApplication sharedApplication] openURL:url];
    }
    
    // send sms: to Messages.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"sms"])) {
        return ![[UIApplication sharedApplication] openURL:url];
    }
    
    // load local file and http/https webpages in webview
    return YES;
}

- (void)onRotationChange:(UIInterfaceOrientation)toInterfaceOrientation {
    
    if(![parentViewController shouldAutorotateToInterfaceOrientation:toInterfaceOrientation]) {
        return;
    }
    
    switch (toInterfaceOrientation) {
        case UIDeviceOrientationPortrait:
            [webView stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return 0;});window.onorientationchange();"];
            break;
        case UIDeviceOrientationLandscapeLeft:
            [webView stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return 90;});window.onorientationchange();"];
            break;
        case UIDeviceOrientationLandscapeRight:
            [webView stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return -90;});window.onorientationchange();"];
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            [webView stringByEvaluatingJavaScriptFromString:@"window.__defineGetter__('orientation',function(){return 180;});window.onorientationchange();"];
            break;
        default:
            break;
    }
}

- (void)orientationChanged:(NSNotification *)notification {
    [self onRotationChange:[UIDevice currentDevice].orientation];
}

- (void)populateJavascriptEnvironment {
    
    //this will inject the current device orientation
    [self onRotationChange:[UIDevice currentDevice].orientation];
    
    NSString *model = [UIDevice currentDevice].model;
    NSString *js = [NSString stringWithFormat:@"devicemodel=\"%@\"", model];
    [webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)webViewDidStartLoad:(UIWebView *)wv {
    [self populateJavascriptEnvironment];
    
    [self doTransition];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {
}

- (void)webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    
    if (error.code == NSURLErrorCancelled)
        return;
    UALOG(@"Failed to load message: %@", error);
    UIAlertView *someError = [[UIAlertView alloc] initWithTitle:UA_INBOX_TR(@"UA_Ooops")
                                                        message:UA_INBOX_TR(@"UA_Error_Fetching_Message")
                                                       delegate:self
                                              cancelButtonTitle:UA_INBOX_TR(@"UA_OK")
                                              otherButtonTitles:nil];
    [someError show];
    [someError release];
}


/**
 * Removes the window background and calls the animation of the window
 */
-(void)closePopupWindow
{
    //remove the shade
    [[bigPanelView viewWithTag: kShadeViewTag] removeFromSuperview];    
    [self performSelector:@selector(closePopupWindowAnimate) withObject:nil afterDelay:0.1];
    
}

/**
 * Animates the window and when done removes all views from the view hierarchy
 * since they are all only retained by their superview this also deallocates them
 * finally deallocate the class instance
 */
-(void)closePopupWindowAnimate
{
    
    //faux view
    __block UIView* fauxView = [[UIView alloc] initWithFrame: CGRectMake(10, 10, 200, 200)];
    [bgView addSubview: fauxView];

    //run the animation
    UIViewAnimationOptions options = UIViewAnimationOptionTransitionFlipFromLeft |
    UIViewAnimationOptionAllowUserInteraction    |
    UIViewAnimationOptionBeginFromCurrentState;
    
    //hold to the bigPanelView, because it'll be removed during the animation
    [bigPanelView retain];
    
    [UIView transitionFromView:bigPanelView toView:fauxView duration:0.5 options:options completion:^(BOOL finished) {

        //when popup is closed, remove all the views
        for (UIView* child in bigPanelView.subviews) {
            [child removeFromSuperview];
        }
        for (UIView* child in bgView.subviews) {
            [child removeFromSuperview];
        }
        [bigPanelView release];
        [bgView removeFromSuperview];
        
        [self release];
    }];
}

- (void)dealloc {
    self.message = nil;
    self.webView = nil;
    [parentViewController release];
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIDeviceOrientationDidChangeNotification 
                                                  object:nil];
}

@end