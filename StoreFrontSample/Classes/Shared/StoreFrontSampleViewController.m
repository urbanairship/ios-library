/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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
#import "StoreFrontSampleViewController.h"
#import "StoreFrontSampleAppDelegate.h"
#import "UAirship.h"
#import "UAStoreFront.h"
#import "UAStoreFrontUI.h"

@implementation StoreFrontSampleViewController

@synthesize version;

// When the shop button is clicked, display storefront.
-(IBAction)shop:(id)sender {
    // Recommended way to present StoreFront. Alternatively you can open to a specific product detail.
    //[StoreFront displayStoreFront:self withProductID:@"oxygen34"];
	[UAStoreFront displayStoreFront:self animated:YES];
    
	// Specify the sorting of the list of products.
    [UAStoreFront setOrderBy:UAContentsDisplayOrderPrice ascending:YES];

}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.version.text = [NSString stringWithFormat:@"StoreFront Version: %@", [StoreFrontVersion get]];
    [UAStoreFront useCustomUI:[UAStoreFrontUI class]];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;

    // StoreFront will rotate to what ever orientations your parent view
    // allows.

    //    if (interfaceOrientation == UIInterfaceOrientationLandscapeRight) {
    //        return YES;
    //    }
    //    return NO;
}

- (void) dealloc {
    [version release];
    [super dealloc];
}

@end
