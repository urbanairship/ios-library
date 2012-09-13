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

#import <QuartzCore/QuartzCore.h>
#import "UAStoreFrontCellView.h"
#import "UAGlobal.h"
#import "UAStoreFront.h"
#import "UAUtils.h"
#import "UAStoreFrontUI.h"


@implementation UAStoreFrontCellView
@synthesize title, description, price, progress, product, priceColor, priceBgColor, priceBorderColor;
@synthesize descriptionHidden, progressHidden;

- (id)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
        self.backgroundColor = [UIColor clearColor];
        product = nil;
        title = nil;
        description = nil;
        price = nil;
        progress = nil;
        priceColor = nil;
        priceBgColor = nil;
        priceBorderColor = nil;
        progressHidden = YES;
        highlighted = FALSE;
    }

    return self;
}


- (void)dealloc {
    product = nil;
    RELEASE_SAFELY(title);
    RELEASE_SAFELY(description);
    RELEASE_SAFELY(price);
    RELEASE_SAFELY(progress);
    RELEASE_SAFELY(priceColor);
    RELEASE_SAFELY(priceBgColor);
    RELEASE_SAFELY(priceBorderColor);

    [super dealloc];
}

- (void)setHighlighted:(BOOL)h {
    if (highlighted != h) {
        highlighted = h;
        [self setNeedsDisplay];
    }
}

- (void)setSelected:(BOOL)s {
    if (selected != s) {
        selected = s;
        [self setNeedsDisplay];
    }
}

#pragma mark -
#pragma mark Refresh UI

- (void)refreshCellView {
    self.title = product.title;
    self.description = product.productDescription;
    
    [self setNeedsDisplay];
}

- (void)refreshCellViewWithProductStatus:(UAProductStatus)status {

    switch (status) {
        case UAProductStatusUnpurchased:
        case UAProductStatusInstalled:
        case UAProductStatusPurchased:
        case UAProductStatusHasUpdate:
            descriptionHidden = NO;
            progressHidden = YES;
            break;
        case UAProductStatusDownloading:
            descriptionHidden = YES;
            progressHidden = NO;
            break;
        case UAProductStatusPurchasing:
        case UAProductStatusDecompressing:
        case UAProductStatusVerifyingReceipt:
            descriptionHidden = YES;
            progressHidden = YES;
            break;
        default:
            break;
    }

    [self setNeedsDisplay];
}

- (void)refreshProgressView:(float)p {
    self.progress = [NSString stringWithFormat:@"%@ / %@",
                          [UAUtils getReadableFileSizeFromBytes:product.fileSize*p],
                          [UAUtils getReadableFileSizeFromBytes:product.fileSize]];
    [self setNeedsDisplay];
}


- (void)refreshPriceLabelView:(UAProductStatus)status {
    //update color
    UAStoreFrontUI *ui = [UAStoreFrontUI shared];
    NSString *text;
    UIColor *textColor, *bgColor, *borderColor;
    if (status == UAProductStatusHasUpdate) {
        text = UA_SF_TR(@"UA_update_available");
        borderColor = textColor = ui.updateFGColor;
        bgColor = ui.updateBGColor;
    } else if (status == UAProductStatusPurchased) {
        text = UA_SF_TR(@"UA_not_downloaded");
        borderColor = textColor = ui.updateFGColor;
        bgColor = ui.updateBGColor;
    } else if (status == UAProductStatusInstalled) {
        text = UA_SF_TR(@"UA_installed");
        borderColor = textColor = ui.installedFGColor;
        bgColor = ui.installedBGColor;
    } else if (status == UAProductStatusDownloading 
               || status == UAProductStatusPurchasing 
               || status == UAProductStatusVerifyingReceipt
               || status == UAProductStatusDecompressing) {
        text = UA_SF_TR(@"UA_downloading");
        textColor = borderColor = ui.downloadingFGColor;
        bgColor = ui.downloadingBGColor;
    } else {
        text = self.product.price;
        textColor = ui.priceFGColor;
        borderColor = ui.priceBorderColor;
        bgColor = ui.priceBGColor;
    }

    self.price = text;
    self.priceColor = textColor;
    self.priceBgColor = bgColor;
    self.priceBorderColor = borderColor;

    [self setNeedsDisplay];
}

static void addRoundedRectToPath(CGContextRef context, CGRect rect,
                                 float ovalWidth,float ovalHeight)
{
    float fw, fh;
    if (ovalWidth == 0 || ovalHeight == 0) { // 1
        CGContextAddRect(context, rect);
        return;
    }
    CGContextSaveGState(context); // 2
    CGContextTranslateCTM (context, CGRectGetMinX(rect), // 3
                           CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight); // 4
    fw = CGRectGetWidth (rect) / ovalWidth; // 5
    fh = CGRectGetHeight (rect) / ovalHeight; // 6
    CGContextMoveToPoint(context, fw, fh/2); // 7
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1); // 8
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1); // 9
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1); // 10
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1); // 11
    CGContextClosePath(context); // 12
    CGContextRestoreGState(context); // 13
}

- (float)getWidth:(NSString *)string {
    CGSize size;
    size = [string sizeWithFont:[UAStoreFrontUI shared].cellPriceFont];
    return size.width;
}

#define RIGHT_BOUNDARY  18.0
- (void)drawRect:(CGRect)r {
    CGRect rect;
    UIColor *fontColor;
    float width = self.frame.size.width;

    if (highlighted || selected) {
        fontColor = [UIColor whiteColor];
    } else {
        fontColor = [UIColor blackColor];
    }

    [fontColor set];
    rect = CGRectMake(76, 11, width-RIGHT_BOUNDARY-76, 20);
    [title drawInRect:rect
             withFont:[UAStoreFrontUI shared].cellTitleFont
        lineBreakMode:UILineBreakModeTailTruncation
            alignment:UITextAlignmentLeft];

    float w = [self getWidth:price];
    CGContextRef context = UIGraphicsGetCurrentContext();
    addRoundedRectToPath(context, CGRectMake(width-RIGHT_BOUNDARY-w-3, 4, w+6, 24), 5.0f, 5.0f);
    CGContextSetFillColorWithColor(context, [priceBorderColor CGColor]);
    CGContextFillPath(context);

    context = UIGraphicsGetCurrentContext();
    addRoundedRectToPath(context, CGRectMake(width-RIGHT_BOUNDARY-w-2, 5, w+4, 22), 5.0f, 5.0f);
    CGContextSetFillColorWithColor(context, [priceBgColor CGColor]);
    CGContextFillPath(context);

    [priceColor set];
    rect = CGRectMake(width-RIGHT_BOUNDARY-w, 8, w, 20);
    [price drawInRect:rect
             withFont:[UAStoreFrontUI shared].cellPriceFont
        lineBreakMode:UILineBreakModeTailTruncation
            alignment:UITextAlignmentCenter];

    if (descriptionHidden == NO) {
        [fontColor set];
        rect = CGRectMake(77, 31, width-RIGHT_BOUNDARY-77, 33);
        [description drawInRect:rect
                       withFont:[UAStoreFrontUI shared].cellDescriptionFont
                  lineBreakMode:UILineBreakModeTailTruncation
                      alignment:UITextAlignmentLeft];
    }

    if (progressHidden == NO) {
        [fontColor set];
        rect = CGRectMake(77, 37, width-RIGHT_BOUNDARY-77, 20);
        [progress drawInRect:rect
                    withFont:[UAStoreFrontUI shared].cellProgressFont
               lineBreakMode:UILineBreakModeTailTruncation
                   alignment:UITextAlignmentLeft];
    }

}

@end
