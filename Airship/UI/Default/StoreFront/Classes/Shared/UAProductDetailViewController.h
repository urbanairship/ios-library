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

#import <UIKit/UIKit.h>
#import "UAProduct.h"
#import "UAStoreFront.h"

@class UAGradientButton;

#define kCellPaddingHeight 30

@interface UAProductDetailViewController : UIViewController
<UITableViewDelegate, UITableViewDataSource, UAProductObserverProtocol, UIWebViewDelegate> {
    IBOutlet UILabel* productTitle;
    IBOutlet UAAsyncImageView* iconContainer;
    IBOutlet UILabel* revision;
    IBOutlet UILabel* fileSize;
    IBOutlet UITableView *detailTable;
    IBOutlet UAGradientButton* priceButton;
    UIBarButtonItem *buyButton;
    BOOL wasBackgrounded;
    UAProduct* product;
    int webViewHeight;
}

@property (nonatomic, retain) UAProduct *product;
@property (nonatomic, retain) IBOutlet UILabel* productTitle;
@property (nonatomic, retain) IBOutlet UAAsyncImageView* iconContainer;
@property (nonatomic, retain) IBOutlet UAGradientButton* priceButton;
@property (nonatomic, retain) IBOutlet UILabel* revision;
@property (nonatomic, retain) IBOutlet UILabel* fileSize;
@property (nonatomic, retain) IBOutlet UILabel* revisionHeading;
@property (nonatomic, retain) IBOutlet UILabel* fileSizeHeading;
@property (nonatomic, retain) IBOutlet UITableView *detailTable;

- (IBAction)purchase:(id)sender;
- (void)refreshUI;
- (void)refreshBuyButton;

- (void)enterBackground;
- (void)enterForeground;

- (NSString *)constructHtmlForWebViewWithDescription:(NSString *)description AndImageURL:(NSURL *)imageURL;


@end
