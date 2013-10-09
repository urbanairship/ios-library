//
//  UAWebViewTools.m
//  InboxSampleLib
//
//  Created by Jeff Towle on 10/8/13.
//
//

#import "UAWebViewTools.h"

#import "UAInboxMessage.h"

@implementation UAWebViewTools


+ (NSURL *)createValidPhoneNumberUrlFromUrl:(NSURL *)url {

    NSString *decodedUrlString = [url.absoluteString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSCharacterSet *characterSet = [[NSCharacterSet characterSetWithCharactersInString:@"+-.0123456789"] invertedSet];
    NSString *strippedNumber = [[decodedUrlString componentsSeparatedByCharactersInSet:characterSet] componentsJoinedByString:@""];

    NSString *scheme = [decodedUrlString hasPrefix:@"sms"] ? @"sms:" : @"tel:";

    return [NSURL URLWithString:[scheme stringByAppendingString:strippedNumber]];
}

+ (BOOL)webView:(UIWebView *)wv shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
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

                 // Set the url scheme to http, as it could be itms which will cause the store to launch twice (undesireable)
                 NSString *stringURL = [NSString stringWithFormat:@"http://%@%@", url.host, url.path];
                 return ![[UIApplication sharedApplication] openURL:[NSURL URLWithString:stringURL]];
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
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return ![[UIApplication sharedApplication] openURL:validPhoneUrl];
    }

    // send sms: to Messages.app
    else if ((navigationType == UIWebViewNavigationTypeLinkClicked) && ([[url scheme] isEqualToString:@"sms"])) {
        NSURL *validPhoneUrl = [self createValidPhoneNumberUrlFromUrl:url];
        return ![[UIApplication sharedApplication] openURL:validPhoneUrl];
    }
    
    // load local file and http/https webpages in webview
    return YES;
}

@end
