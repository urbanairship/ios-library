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

#import "UAStoreFrontCellTest.h"
#import "UAGlobal.h"
#import "UAProduct.h"
#import "UAStoreFrontUI.h"
#import "UAUtils.h"

@implementation MockedUAProduct : UAProduct
- (void)notifyInventoryObservers:(UAProductStatus)aStatus{};
- (void)resetStatus{};
@end


@implementation UAStoreFrontCellTest

- (void)setUp {
    cell = [[UAStoreFrontCell alloc] initWithStyle:UITableViewCellStyleDefault
                                   reuseIdentifier:@"store-front-cell"];
    product = [[UAProduct productFromDictionary:
                [NSDictionary dictionaryWithObjectsAndKeys:
                 @"dummy_product_id", @"product_id",
                 @"dummy_preview_url", @"preview_url",
                 @"download_url", @"download_url",
                 @"icon_url", @"icon_url",
                 @"dummy_product_name", @"name",
                 @"1", @"free",
                 @"dummy_product_description", @"description",
                 @"5", @"current_revision",
                 @"12.8", @"file_size",
                 nil]] retain];
}

- (void)_testRefreshWithProductStatus:(UAProductStatus)pStatus
                         productPrice:(NSString*)pPrice
                 expectProgressHidden:(BOOL)expectProgressHidden
                 expectActivityHidden:(BOOL)expectActivityHidden
              expectDescriptionHidden:(BOOL)expectDescriptionHidden
                      expectPriceText:(NSString*)expectPriceText {

    product.price = pPrice;
    product.status = pStatus;
    STAssertEquals(cell.cellView.progressHidden, expectProgressHidden, nil);
    STAssertEquals(cell.activityView.hidden, expectActivityHidden, nil);
    STAssertEquals(cell.cellView.descriptionHidden, expectDescriptionHidden, nil);
    STAssertEqualStrings(cell.cellView.price, expectPriceText, nil);
}


- (void)testRefreshWithProductStatus {
    product.status = UAProductStatusUnpurchased;
    product.progress = 0.2f;
    cell.product = product;
    
    // test the initial status
    [self _testRefreshWithProductStatus:UAProductStatusUnpurchased
                           productPrice:nil expectProgressHidden:YES
                   expectActivityHidden:YES expectDescriptionHidden:NO
                        expectPriceText:UA_SF_TR(@"UA_Free")];
    STAssertEqualStrings(cell.cellView.title, @"dummy_product_name", nil);
    STAssertEqualStrings(cell.cellView.description, @"dummy_product_description", nil);
    NSString *expectProgressText =  [NSString stringWithFormat:@"%@ / %@",
     [UAUtils getReadableFileSizeFromBytes:product.fileSize*product.progress],
                                     [UAUtils getReadableFileSizeFromBytes:product.fileSize]];
    STAssertEqualStrings(cell.cellView.progress, expectProgressText, nil);

    product.isFree = NO;

    [self _testRefreshWithProductStatus:UAProductStatusWaiting
                           productPrice:@"123" expectProgressHidden:YES
                   expectActivityHidden:NO expectDescriptionHidden:YES
                        expectPriceText:UA_SF_TR(@"UA_downloading")];

    [self _testRefreshWithProductStatus:UAProductStatusDownloading
                           productPrice:@"123" expectProgressHidden:NO
                   expectActivityHidden:YES expectDescriptionHidden:YES
                        expectPriceText:UA_SF_TR(@"UA_downloading")];

    [self _testRefreshWithProductStatus:UAProductStatusPurchased
                           productPrice:@"123" expectProgressHidden:YES
                   expectActivityHidden:YES expectDescriptionHidden:NO
                        expectPriceText:UA_SF_TR(@"UA_not_downloaded")];

    [self _testRefreshWithProductStatus:UAProductStatusInstalled
                           productPrice:@"123" expectProgressHidden:YES
                   expectActivityHidden:YES expectDescriptionHidden:NO
                        expectPriceText:UA_SF_TR(@"UA_installed")];

    [self _testRefreshWithProductStatus:UAProductStatusHasUpdate
                           productPrice:@"123" expectProgressHidden:YES
                   expectActivityHidden:YES expectDescriptionHidden:NO
                        expectPriceText:UA_SF_TR(@"UA_update_available")];
    
    // change the product status to test the price label
    [self _testRefreshWithProductStatus:UAProductStatusUnpurchased
                           productPrice:@"1234" expectProgressHidden:YES
                   expectActivityHidden:YES expectDescriptionHidden:NO
                        expectPriceText:@"1234"];
}

- (void)tearDown {
    RELEASE_SAFELY(cell);
    RELEASE_SAFELY(product);
}

@end
