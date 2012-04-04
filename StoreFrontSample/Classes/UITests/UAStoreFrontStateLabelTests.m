/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

#import "UAStoreFrontStateLabelTests.h"
#import "UAStoreFrontUI.h"
#import "UAInventory.h"

@implementation UAStoreFrontStateLabelTests

#pragma mark -
#pragma mark StoreFront Show

- (void)testShowWithInventoryStatusFaild {
    [[UAStoreFront shared].inventory setStatus:UAInventoryStatusFailed];
    STAssertEqualStrings(iPhoneViewController.statusLabel.text, UA_SF_TR(@"UA_Status_Failed"), @"Status Label Text test faild. :-(");
    STAssertFalseNoThrow(iPhoneViewController.statusLabel.hidden, @"Status Label didn't show. :-(");
    STAssertFalseNoThrow(iPhoneViewController.loadingView.hidden, @"Loading View didn't show. :-(");
    STAssertFalseNoThrow(iPhoneViewController.activityView.hidden, @"Activity View didn't show. :-(");
    
    STAssertEqualStrings(iPadViewController.statusLabel.text, UA_SF_TR(@"UA_Status_Failed"), @"Status Label Text test faild. :-(");
    STAssertFalseNoThrow(iPadViewController.statusLabel.hidden, @"Status Label didn't show. :-(");
    STAssertFalseNoThrow(iPadViewController.loadingView.hidden, @"Loading View didn't show. :-(");
    STAssertFalseNoThrow(iPadViewController.activityView.hidden, @"Activity View didn't show. :-(");
}

- (void)testShowWithInventoryStatusLoadedAndNoProduct {
    STAssertTrueNoThrow([UAStoreFront productsForType:ProductTypeAll].count == 0, @":-(");
    [[UAStoreFront shared].inventory setStatus:UAInventoryStatusLoaded];
    STAssertEqualStrings(iPhoneViewController.statusLabel.text, UA_SF_TR(@"UA_No_Content"), @"Status Label Text test faild. :-(");
    STAssertFalseNoThrow(iPhoneViewController.statusLabel.hidden, @"Status Label Didn't Show. :-(");
    STAssertFalseNoThrow(iPhoneViewController.loadingView.hidden, @"Loading View didn't show. :-(");
    STAssertFalseNoThrow(iPhoneViewController.activityView.hidden, @"Activity View didn't show. :-(");
    
    STAssertEqualStrings(iPadViewController.statusLabel.text, UA_SF_TR(@"UA_No_Content"), @"Status Label Text test faild. :-(");
    STAssertFalseNoThrow(iPadViewController.statusLabel.hidden, @"Status Label Didn't Show. :-(");
    STAssertFalseNoThrow(iPadViewController.loadingView.hidden, @"Loading View didn't show. :-(");
    STAssertFalseNoThrow(iPadViewController.activityView.hidden, @"Activity View didn't show. :-(");
}

- (void)testShowWithInventoryStatusLoadedAndProducts {
    NSMutableArray *products = (NSMutableArray *)[UAStoreFront productsForType:ProductTypeAll];
    UAProduct *first = [[[UAProduct alloc] init] autorelease];
    [products addObject:first];
    UAProduct *second = [[[UAProduct alloc] init] autorelease];
    [products addObject:second];

    [[UAStoreFront shared].inventory setStatus:UAInventoryStatusLoaded];
    STAssertTrueNoThrow(products.count == 2, @"Products count is error. :-(");
    STAssertTrueNoThrow(iPhoneViewController.loadingView.hidden, @"Loading View didn't hidden. :-(");
    STAssertTrueNoThrow(iPhoneViewController.activityView.hidden, @"Activity View didn't hidden. :-(");
    
    STAssertTrueNoThrow(iPadViewController.loadingView.hidden, @"Loading View didn't hidden. :-(");
    STAssertTrueNoThrow(iPadViewController.activityView.hidden, @"Activity View didn't hidden. :-(");
}


-(void)tearDown {
    [UAStoreFront unregisterObserver:iPhoneViewController];
    [UAStoreFront unregisterObserver:iPadViewController];
    RELEASE_SAFELY(iPhoneViewController.statusLabel);
    RELEASE_SAFELY(iPhoneViewController.loadingView);
    RELEASE_SAFELY(iPhoneViewController.activityView);
    RELEASE_SAFELY(iPhoneViewController);
    RELEASE_SAFELY(iPadViewController.statusLabel);
    RELEASE_SAFELY(iPadViewController.loadingView);
    RELEASE_SAFELY(iPadViewController.activityView);
    RELEASE_SAFELY(iPadViewController);
}

- (void)setUp {
    iPhoneViewController = [[UAStoreFrontViewController alloc] init];
    iPhoneViewController.loadingView = [[UIView alloc] init];
    iPhoneViewController.statusLabel = [[UILabel alloc] init];
    iPhoneViewController.activityView = [[UIActivityIndicatorView alloc] init];
    [iPhoneViewController.loadingView addSubview:iPhoneViewController.statusLabel];
    [iPhoneViewController.loadingView addSubview:iPhoneViewController.activityView];
    [iPhoneViewController.view addSubview:iPhoneViewController.loadingView];
    
    iPadViewController = [[UAStoreFrontiPadViewController alloc] init];
    iPadViewController.loadingView = [[UIView alloc] init];
    iPadViewController.statusLabel = [[UILabel alloc] init];
    iPadViewController.activityView = [[UIActivityIndicatorView alloc] init];
    [iPadViewController.loadingView addSubview:iPadViewController.statusLabel];
    [iPadViewController.loadingView addSubview:iPadViewController.activityView];
    [iPadViewController.view addSubview:iPadViewController.loadingView];
    
    [UAStoreFront registerObserver:iPhoneViewController];
    [UAStoreFront registerObserver:iPadViewController];
    
    [[UAStoreFront shared].inventory setStatus:UAInventoryStatusDownloading];
    STAssertEqualStrings(iPhoneViewController.statusLabel.text, UA_SF_TR(@"UA_Loading"), nil);
    STAssertEqualStrings(iPadViewController.statusLabel.text, UA_SF_TR(@"UA_Loading"), nil);
}

@end
