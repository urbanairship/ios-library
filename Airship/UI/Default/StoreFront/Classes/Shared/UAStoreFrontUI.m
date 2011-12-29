/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.

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
@synthesize isiPad;
@synthesize uaWindow;
@synthesize originalWindow;
@synthesize isVisible;
@synthesize localizationBundle;

@synthesize cellPriceFont;
@synthesize cellTitleFont;
@synthesize cellDescriptionFont;
@synthesize detailDescriptionFont;
@synthesize cellProgressFont;
@synthesize detailTitleFont;
@synthesize detailPriceFont;
@synthesize detailMetadataFont;
@synthesize cellEvenBackgroundColor;
@synthesize cellOddBackgroundColor;

static BOOL runiPhoneTargetOniPad = NO;

+ (void)setRuniPhoneTargetOniPad:(BOOL)value {
    runiPhoneTargetOniPad = value;
}

-(void)dealloc {    
    RELEASE_SAFELY(rootViewController);
    RELEASE_SAFELY(productListViewController);
    RELEASE_SAFELY(uaWindow);
    RELEASE_SAFELY(originalWindow);
    RELEASE_SAFELY(alertHandler);
    RELEASE_SAFELY(localizationBundle);
    
    RELEASE_SAFELY(cellPriceFont);
    RELEASE_SAFELY(cellTitleFont);
    RELEASE_SAFELY(cellDescriptionFont);
    RELEASE_SAFELY(cellProgressFont);
    RELEASE_SAFELY(detailDescriptionFont);
    RELEASE_SAFELY(detailPriceFont);
    RELEASE_SAFELY(detailMetadataFont);
    RELEASE_SAFELY(detailTitleFont);
    RELEASE_SAFELY(cellEvenBackgroundColor);
    RELEASE_SAFELY(cellOddBackgroundColor);
    
    [super dealloc];
}

-(id)init {
    UALOG(@"Initialize UAStoreFrontUI.");

    if (self = [super init]) {
        NSString* path = [[[NSBundle mainBundle] resourcePath]
                          stringByAppendingPathComponent:@"UAStoreFrontLocalization.bundle"];

        self.localizationBundle = [NSBundle bundleWithPath:path];

        if ((UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) && !runiPhoneTargetOniPad) {
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
        
        // Default fonts
        cellDescriptionFont = [[UIFont fontWithName:@"Helvetica" size:13] retain];
        cellTitleFont = [[UIFont fontWithName:@"Helvetica-Bold" size:18] retain];
        cellPriceFont = [[UIFont fontWithName:@"Helvetica" size:14] retain];
        cellProgressFont = [[UIFont fontWithName:@"Helvetica" size:13] retain];
        detailDescriptionFont = [[UIFont systemFontOfSize:16] retain];
        detailTitleFont = nil;
        detailPriceFont = nil;
        detailMetadataFont = nil;
        cellOddBackgroundColor = [RGBA(255, 255, 255, 1) retain];
        cellEvenBackgroundColor = [RGBA(240, 242, 243, 1) retain];
    }
    
    return self;
}

+ (void)displayStoreFront:(UIViewController *)viewController animated:(BOOL)animated {
    UAStoreFrontUI* ui = [UAStoreFrontUI shared];
    ui->animated = animated;

    // reset the view navigation to the product list
    [ui.productListViewController.navigationController popToRootViewControllerAnimated:NO];

    // if iPhone/iPod
    if (!ui.isiPad) {
        [viewController presentModalViewController:ui.rootViewController animated:animated];
    } else {
        // else iPad
        if (ui.uaWindow == nil) {
            ui.uaWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            [ui.uaWindow addSubview:ui.rootViewController.view];
        }

        ui.originalWindow = viewController.view.window;

        [ui.rootViewController viewWillAppear:animated];
        [ui.uaWindow makeKeyAndVisible];
        ui.originalWindow.hidden = YES;
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
        // if iPad
        [ui.rootViewController viewWillDisappear:ui->animated];
    }

    UIViewController *presentingViewController = nil;
    if ([ui.rootViewController respondsToSelector:@selector(presentingViewController)]) {
        presentingViewController = [ui.rootViewController presentingViewController]; //iOS5 method
    } else {
        presentingViewController = ui.rootViewController.parentViewController;// <= 4.x
    }
    
    if (presentingViewController != nil) {
        // for iPhone/iPod displayStoreFront:animated:
        [ui.rootViewController dismissModalViewControllerAnimated:ui->animated];

    } else if (ui.rootViewController.view.superview == ui.uaWindow) {

        // For iPad displayStoreFront:animated:
        // Return control to original window
        [ui.originalWindow makeKeyAndVisible];
        ui.originalWindow = nil;

        [ui.rootViewController.view removeFromSuperview];
        ui.uaWindow = nil;

    } else {
        // For other circumstances. e.g custom showing rootViewController or changed the showing code of StoreFront
        UALOG(@"UAStoreFrontUI rootViewController appears to be customized. Add your own quit logic here");
    }

    ui->isVisible = NO;
}

+ (id<UAStoreFrontAlertProtocol>)getAlertHandler {
    UAStoreFrontUI* ui = [UAStoreFrontUI shared];
    
    return ui->alertHandler;
}

@end
