/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
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

#import "UAStoreFrontUI.h"
#import "UAStoreFrontViewController.h"
#import "UAStoreFrontSplitViewController.h"


@implementation UAStoreFrontUI

SINGLETON_IMPLEMENTATION(UAStoreFrontUI)

@synthesize rootViewController;
@synthesize productListViewController;
@synthesize originalSubviews;
@synthesize originalWindow;
@synthesize isiPad;
@synthesize uaWindow;
@synthesize isVisible;
@synthesize localizationBundle;

static BOOL runiPhoneTargetOniPad = NO;
+ (void)setRuniPhoneTargetOniPad:(BOOL)value {
    runiPhoneTargetOniPad = value;
}

-(void)dealloc {    
    RELEASE_SAFELY(rootViewController);
    RELEASE_SAFELY(productListViewController);
    RELEASE_SAFELY(originalWindow);
    RELEASE_SAFELY(originalSubviews);
    RELEASE_SAFELY(uaWindow);
    RELEASE_SAFELY(alertHandler);
    RELEASE_SAFELY(localizationBundle);

    [super dealloc];
}

-(id)init {
    UALOG(@"Initialize StoreFront.");

    if (self = [super init]) {
        NSString* path = [[[NSBundle mainBundle] resourcePath]
                          stringByAppendingPathComponent:@"UAStoreFrontLocalization.bundle"];
        self.localizationBundle = [NSBundle bundleWithPath:path];
        
        // To partially support rotation when present by displayStoreFront
        userOrientation = UIInterfaceOrientationPortrait;
        storeOrientation = UIInterfaceOrientationPortrait;

        NSString *deviceType = [UIDevice currentDevice].model;
        if ([deviceType hasPrefix:@"iPad"] && !runiPhoneTargetOniPad) {
            isiPad = YES;
            UAStoreFrontSplitViewController *svc = [[UAStoreFrontSplitViewController alloc] init];
            productListViewController = [[svc productListViewController] retain];
            rootViewController = (UIViewController *)svc;
        } else {
            productListViewController = [[UAStoreFrontViewController alloc]
                                         initWithNibName:@"UAStoreFront" bundle:nil];
            rootViewController = [[UINavigationController alloc] initWithRootViewController:productListViewController];
        }
        alertHandler = [[UAStoreFrontAlertHandler alloc] init];
        isVisible = NO;
    }
    return self;
}

+ (void)displayStoreFront:(UIViewController *)viewController animated:(BOOL)animated {
    UAStoreFrontUI* ui = [UAStoreFrontUI shared];
    ui->animated = animated;

    if (!ui.isiPad) {
        [viewController presentModalViewController:ui.rootViewController animated:animated];
    } else {
        if (ui.uaWindow == nil) {
            ui.uaWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            [ui.uaWindow addSubview:ui.rootViewController.view];
        }
        [ui.rootViewController viewWillAppear:animated];
        [ui.uaWindow makeKeyAndVisible];
    }
    ui->isVisible = YES;
}

+ (void)displayStoreFront:(UIViewController *)viewController withProductID:(NSString *)productID animated:(BOOL)animated {
    UAStoreFrontUI* ui = [UAStoreFrontUI shared];
    [UAStoreFrontUI displayStoreFront:viewController animated:animated];
    [ui.productListViewController loadProduct:productID];
}


+ (void)quitStoreFront {
    UAStoreFrontUI* ui = [UAStoreFrontUI shared];

    if (ui.isiPad) {
        [ui.rootViewController viewWillDisappear:ui->animated];
    }

    if (ui.rootViewController.parentViewController != nil) {
        // for iPhone displayStoreFront:animated:
        [ui.rootViewController dismissModalViewControllerAnimated:ui->animated];

        // KEEP in case rotating/positioning bug happens again
        //UIViewController *con = sf.rootViewController.parentViewController;
        //[con dismissModalViewControllerAnimated:sf->animated];
        // Workaround. ModalViewController does not handle resizing correctly if
        // dismissed in landscape when status bar is visible
        //if ([UIApplication sharedApplication].statusBarHidden == NO) {
        //    con.view.frame = UAFrameForCurrentOrientation(con.view.frame);
        //}
    } else if (ui.rootViewController.view.superview == ui.uaWindow) {
        // for iPad displayStoreFront:animated:
        ui.uaWindow.hidden = YES;
    } else if (ui.rootViewController.view.superview == ui.originalWindow) {
        // For displayStoreFront
        ui->storeOrientation = [UIApplication sharedApplication].statusBarOrientation;
        [ui.rootViewController.view removeFromSuperview];
        [UIApplication sharedApplication].statusBarOrientation = ui->userOrientation;
        for (UIView *view in ui.originalSubviews) {
            [ui.originalWindow addSubview:view];
        }
    } else if (ui.rootViewController.view.superview != nil) {
        // For makeStoreFrontView
        [ui.rootViewController.view removeFromSuperview];
    } else {
        // For other circumstances. e.g custom showing rootViewController
        // or changed the showing code of StoreFront
        UALOG(@"StoreFront rootViewController did not add to the application in an official way. \
              You may want to put your own quiting code here.");
    }

    ui->isVisible = NO;
}

+ (id<UAStoreFrontAlertProtocol>)getAlertHandler {
    UAStoreFrontUI* ui = [UAStoreFrontUI shared];
    return ui->alertHandler;
}

@end
