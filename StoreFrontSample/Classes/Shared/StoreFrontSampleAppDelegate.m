/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
#import "StoreFrontSampleAppDelegate.h"
#import "UAirship.h"
#import "UAStoreFront.h"
#import "UAInventory.h"
#import "UAStoreFrontUI.h"

@implementation StoreFrontSampleAppDelegate

@synthesize window;
@synthesize viewController;
@synthesize navController;
@synthesize tabBarController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    // StoreFront uses SplitViewController on iPad target, but you could customize to
    // use NavigationController on iPad device by uncommenting below line.
    //UAStoreFrontUI.runiPhoneTargetOniPad = YES;

    [window makeKeyAndVisible];

    // Uncomment one of the following three different view controllers
    //[window addSubview: [tabBarController view]];
    //[window addSubview: [navController view]];
    [window addSubview:[viewController view]];

    [self failIfSimulator];

    //Init Airship launch options
    NSMutableDictionary *takeOffOptions = [[[NSMutableDictionary alloc] init] autorelease];
    [takeOffOptions setValue:launchOptions forKey:UAirshipTakeOffOptionsLaunchOptionsKey];
    
    // Create Airship singleton that's used to talk to Urban Airship servers.
    // Please populate AirshipConfig.plist with your info from http://go.urbanairship.com
    [UAirship takeOff:takeOffOptions];

    //Optional if you want to receive StoreFrontDelegate callbacks
    [[UAStoreFront shared] setDelegate:self];
    
    // Register for notifications
    [[UIApplication sharedApplication]
     registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                         UIRemoteNotificationTypeSound |
                                         UIRemoteNotificationTypeAlert)];
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [UAirship land];
}

- (void)dealloc {
    [navController release];
    [tabBarController release];
    [viewController release];
    [window release];
    [super dealloc];
}

- (void)failIfSimulator {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
        UIAlertView *someError = [[UIAlertView alloc] initWithTitle:@"Ooopsie"
                                                            message:@"Can't test StoreKit functionality in the simulator. :-("
                                                           delegate:self
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];

        [someError show];
        [someError release];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    UALOG(@"APN device token: %@", deviceToken);
    // Updates the device token and registers the token with UA
    [[UAirship shared] registerDeviceToken:deviceToken];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *) error {
    UALOG(@"did Fail To Register For Remote Notifications With Error: %@", error);
}

// Copy and paste this method into your AppDelegate to handle push
// notifications for your application while the app is running.
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [[UAirship shared].analytics handleNotification:userInfo];
}

#pragma mark -
#pragma mark StoreFrontDelegate

-(void)productPurchased:(UAProduct*) product {
    UALOG(@"[StoreFrontDelegate] Purchased: %@ -- %@", product.productIdentifier, product.title);
}

-(void)storeFrontWillHide {
    UALOG(@"[StoreFrontDelegate] StoreFront will hide");
}

- (void)productsDownloadProgress:(float)progress count:(int)count {
    //UALOG(@"[StoreFrontDelegate] productsDownloadProgress: %f count: %d", progress, count);
    if (count == 0) {
        UALOG(@"Downloads complete");
    }
}

@end
