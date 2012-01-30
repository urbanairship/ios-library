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

#import "UAUtils.h"
#import "UAViewUtils.h"
#import "UAStoreFrontUI.h"
#import "UAProductDetailViewController.h"
#import "UAAsycImageView.h"
#import "UAGradientButton.h"

// Weak link to this notification since it doesn't exist in iOS 3.x
UIKIT_EXTERN NSString* const UIApplicationDidEnterBackgroundNotification __attribute__((weak_import));
UIKIT_EXTERN NSString* const UIApplicationDidBecomeActiveNotification __attribute__((weak_import));

@implementation UAProductDetailViewController

@synthesize product;
@synthesize productTitle;
@synthesize iconContainer;
@synthesize fileSize;
@synthesize revision;
@synthesize detailTable;
@synthesize revisionHeading;
@synthesize fileSizeHeading;
@synthesize priceButton;

- (void)dealloc {
    self.product = nil;
    RELEASE_SAFELY(fileSize);
    RELEASE_SAFELY(productTitle);
    RELEASE_SAFELY(iconContainer);
    RELEASE_SAFELY(revision);
    RELEASE_SAFELY(detailTable);
    RELEASE_SAFELY(buyButton);
    RELEASE_SAFELY(revisionHeading);
    RELEASE_SAFELY(fileSizeHeading);
    RELEASE_SAFELY(priceButton);
    [super dealloc];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {

        wasBackgrounded = NO;

        IF_IOS4_OR_GREATER(
            if (&UIApplicationDidEnterBackgroundNotification != NULL) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(enterBackground)
                                                             name:UIApplicationDidEnterBackgroundNotification
                                                           object:nil];
            }

            if (&UIApplicationDidBecomeActiveNotification != NULL) {
                [[NSNotificationCenter defaultCenter] addObserver:self
                                                         selector:@selector(enterForeground)
                                                             name:UIApplicationDidBecomeActiveNotification
                                                           object:nil];
            }
                           );

        [self setTitle: UA_SF_TR(@"UA_Details")];
        NSString* buyString = UA_SF_TR(@"UA_Buy");

        buyButton = [[UIBarButtonItem alloc] initWithTitle:buyString
                                                     style:UIBarButtonItemStyleDone
                                                    target:self
                                                    action:@selector(purchase:)];
        
        webViewHeight = 0;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    [UAViewUtils roundView:iconContainer borderRadius:10.0 borderWidth:1.0 color:[UIColor darkGrayColor]];
    
    // Update price button
    priceButton.titleLabel.textColor = kPriceFGColor;
    
    // Font customization
    UAStoreFrontUI *ui = [UAStoreFrontUI shared];
    if (ui.detailTitleFont != nil)
    {
        self.productTitle.font = ui.detailTitleFont;
    }
    
    if (ui.detailPriceFont != nil)
    {
        self.priceButton.titleLabel.font = ui.detailPriceFont;
    }
    
    if (ui.detailMetadataFont != nil)
    {
        self.revision.font = ui.detailMetadataFont;
        self.fileSize.font = ui.detailMetadataFont;
        self.revisionHeading.font = ui.detailMetadataFont;
        self.fileSizeHeading.font = ui.detailMetadataFont;
    }

    if (ui.detailBackgroundColor != nil) {
        self.detailTable.backgroundColor = ui.detailBackgroundColor;
        self.view.backgroundColor = ui.detailBackgroundColor;
    }
    
    [self refreshUI];
}

- (void)viewDidUnload {
    self.productTitle = nil;
    self.iconContainer = nil;
    self.priceButton = nil;
    self.revision = nil;
    self.fileSize = nil;
    self.detailTable = nil;
    self.revisionHeading = nil;
    self.fileSizeHeading = nil;
}

- (void)viewDidDisappear:(BOOL)animated {
    self.product = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

// App is backgrounding, so unregister observers in prep for data reload later
- (void)enterBackground {
    wasBackgrounded = YES;
    self.product = nil;
}

// App is returning to foreground, so get out of detail view since the reloaded
// data may no longer contain this item. This can be triggered by iOS system popups as well.
- (void)enterForeground {
    if(wasBackgrounded) {
        wasBackgrounded = NO;
        self.product = nil;
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark -
#pragma mark Modal/Controller Update Methods

- (void)setProduct:(UAProduct *)value {
    if (value == product) {
        return;
    }
    
    //remove old product
    [product removeObserver:self];
    [product autorelease];
    
    //replace with new product
    product = [value retain];
    [product addObserver:self];
    
    //update UI
    [self refreshUI];
}

#pragma mark -
#pragma mark UAProductObserverProtocol

- (void)productStatusChanged:(NSNumber*)status {
    [self refreshBuyButton];
}

- (void)refreshUI {
    // empty UI when no product associated
    if (product == nil) {
        detailTable.hidden = YES;
        self.navigationItem.rightBarButtonItem = nil;
        return;
    }

    // reset UI for product
    detailTable.hidden = NO;

    // update buy button
    if (self.navigationItem.rightBarButtonItem == nil)
        self.navigationItem.rightBarButtonItem = buyButton;

    [self refreshBuyButton];

    // table header
    productTitle.text = product.title;
    [iconContainer loadImageFromURL:product.iconURL];
    revision.text = [NSString stringWithFormat: @"%d", product.revision];
    fileSize.text = [UAUtils getReadableFileSizeFromBytes:product.fileSize];
    [priceButton setTitle:product.price forState:UIControlStateNormal];

    // resize price frame
    /*
    CGRect frame = price.frame;
    CGFloat frameRightBound = CGRectGetMaxX(frame);
    [price sizeToFit];
    CGRect trimmedFrame = price.frame;
    frame.size.width = trimmedFrame.size.width + 15;
    frame.origin.x = frameRightBound - frame.size.width;
    price.frame = frame;
     */

    [detailTable reloadData];
}

- (void)refreshBuyButton {
    NSString *buttonText = nil;
    if (product.status == UAProductStatusHasUpdate) {
        buttonText = UA_SF_TR(@"UA_Update");
    } else if (product.status == UAProductStatusInstalled) {
        if ([UAStoreFrontUI shared].isiPad) {
            buttonText = UA_SF_TR(@"UA_Download"); // Let's say Download, since there are too many restore labels in iPad view
        } else {
            buttonText = UA_SF_TR(@"UA_Restore");
        }
    } else if (product.status == UAProductStatusPurchased) {
        buttonText = UA_SF_TR(@"UA_Download");
    } else if (product.status == UAProductStatusDownloading 
               || product.status == UAProductStatusPurchasing 
               || product.status == UAProductStatusVerifyingReceipt
               || product.status == UAProductStatusDecompressing) {
        buttonText = UA_SF_TR(@"UA_downloading");
    } else {
        buttonText = UA_SF_TR(@"UA_Buy");
    }
    self.navigationItem.rightBarButtonItem.title = buttonText;

    self.navigationItem.rightBarButtonItem.enabled = YES;
    if (product.status == UAProductStatusDownloading 
        || product.status == UAProductStatusPurchasing 
        || product.status == UAProductStatusVerifyingReceipt
        || product.status == UAProductStatusDecompressing) {
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }
}

#pragma mark -
#pragma mark Action Methods

- (void)purchase:(id)sender {
    self.navigationItem.rightBarButtonItem.enabled = NO;
    [UAStoreFront purchase:product.productIdentifier];
    [self.navigationController popViewControllerAnimated:NO];
}

#pragma mark -
#pragma mark UITableViewDelegate

- (CGFloat) tableView: (UITableView *) tableView heightForRowAtIndexPath: (NSIndexPath *) indexPath {
    if (product.previewURL == nil || webViewHeight == 0) {
        return tableView.rowHeight;
    } else {
        CGFloat height = webViewHeight;
        return height + kCellPaddingHeight;
    }
}

#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UIImage *bgImage = [UIImage imageNamed:@"middle-detail.png"];
    UIImage *stretchableBgImage = [bgImage stretchableImageWithLeftCapWidth:20 topCapHeight:0];
    UIImageView *bgImageView = [[[UIImageView alloc] initWithImage:stretchableBgImage] autorelease];
    
    NSString* text = product.productDescription;
    
    if ([UAStoreFrontUI shared].detailDescriptionTextFormat != nil)
    {
        text = [NSString stringWithFormat:[UAStoreFrontUI shared].detailDescriptionTextFormat, text];
    }
    
    UIFont *font = [UAStoreFrontUI shared].detailDescriptionFont;
    UIWebView *webView = [[[UIWebView alloc] init] autorelease];
    NSString *htmlString = [self constructHtmlForWebViewWithDescription:text AndImageURL:product.previewURL];
    [webView loadHTMLString:htmlString baseURL:nil];
    [webView setBackgroundColor:[UIColor clearColor]];
    [webView setOpaque:0];
    [webView setDelegate:self];
    
    CGFloat height = [text sizeWithFont: font
                      constrainedToSize: CGSizeMake(280.0, 800.0)
                          lineBreakMode: UILineBreakModeWordWrap].height;
    [webView setFrame:CGRectMake(0.0f, 10.0f, 320.0f, height)];
    [webView setBounds:CGRectMake(0.20f, 0.0f, 290.0f, height)];
    [webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                    reuseIdentifier: @"description-cell"]
                             autorelease];
    [cell addSubview:webView];
    [cell setSelectionStyle:UITableViewCellSelectionStyleNone];
    [cell setBackgroundView:bgImageView];
    return cell;
}

#pragma mark -
#pragma mark WebView

- (NSString *)constructHtmlForWebViewWithDescription:(NSString *)description AndImageURL:(NSURL *)imageURL {
    
    UIFont *font = [UAStoreFrontUI shared].detailDescriptionFont;
    
    return [NSString stringWithFormat:@"<html> <body style=\"background-color: transparent; font-family: %@; font-size: %f pt;\"> %@ <div style='text-align: center; margin-top: 10px'><img width=\"%d\" src=\"%@\" /></div> </body> </html>",
            font.familyName, font.pointSize, description, [UAStoreFrontUI shared].previewImageWidth, [imageURL description]];
}

- (void)webViewDidFinishLoad:(UIWebView *)view {
    [view sizeToFit];
    NSString *output = [view stringByEvaluatingJavaScriptFromString:@"document.height;"];
    int currentHeight = [output intValue];
    if (currentHeight == webViewHeight) {
        return;
    }
    webViewHeight = currentHeight;
    [detailTable reloadData];
}

@end
