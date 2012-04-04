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

#import "UAStoreFrontDownloadManagerTests.h"
#import "UATestGlobal.h"
#import "UAInventory+Mocked.h"


@implementation UAStoreFrontDownloadManagerTests

- (BOOL)shouldRunOnMainThread {
    return YES;
}

- (void)setUpClass {
    [self mock:[UAStoreFront class] method:@selector(initProperties) withMethod:@selector(initProperties_with_dummy_skobserver)];
}

- (void)setUp {
    // when init StoreFront, will load pending products from the history file,
    // so should mock the 'loadPendingProducts' method first
    [self mock:[UAStoreFrontDownloadManager class] method:@selector(loadPendingProducts) withMethod:@selector(doNothing)];
}

- (void)tearDown {
    [[UAStoreFront shared] forceRelease];
}

#pragma mark -
#pragma mark Test resume pending products

- (BOOL)checkResumePendingProductsFinished {
    NSDictionary *value = (NSDictionary *)[UATestGlobal shared].value;
    return [value objectForKey:@"resumePendingProductsFinished"] != nil;
}

- (void)_testResumePendingProducts:(NSDictionary*)expectProducts {
    [UADownloadManager removeAllCalls];
    [UAStoreFrontDownloadManager removeAllCalls];
    
    [self mock:[UADownloadManager class] method:@selector(download:) withMethod:@selector(record_call_download:)];
    [self mock:[UADownloadManager class] method:@selector(allDownloadingContents) withMethod:@selector(nothing_allDownloadingContents)];
    [self mock:[UAInventory class] method:@selector(productWithIdentifier:) withMethod:@selector(get_expected_productWithIdentifier:)];
    [self mock:[UAStoreFrontDownloadManager class] method:@selector(resumePendingProducts) withMethod:@selector(record_call_and_continue_resumePendingProducts)];
    [self mock:[UAProduct class] method:@selector(resetStatus) withMethod:@selector(doNothing)];
    
    [UATestGlobal shared].value = [NSMutableDictionary dictionaryWithObject:expectProducts forKey:@"products"];
    
    //manually load pending products from the shared UATestGlobal.value
    [[UAStoreFront shared].downloadManager fake_loadPendingProducts];

    [UAStoreFront loadInventory];
    BOOL timeout = [self spinRunThreadWithTimeOut:60
                                finishedCheckFunc:@selector(checkResumePendingProductsFinished)
                                 processingString:@"Waiting for resume pending product..."];
    GHAssertEquals(timeout, NO, @"Test resume pending products failed. timeout");
    
    int callTimes = [UAStoreFrontDownloadManager getCallTimes:@selector(resumePendingProducts)];
    GHAssertEquals(1, callTimes, [NSString stringWithFormat:@"Test resume pending products failed. @selector(resumePendingProducts) callTimes: %d", callTimes]);
    
    NSArray *allProductIDs = [expectProducts allKeys];
    callTimes = [UADownloadManager getCallTimes:@selector(download:)];
    int expectProductsCount = allProductIDs.count;
    GHAssertEquals(expectProductsCount, callTimes, [NSString stringWithFormat:@"Test resume pending products failed. @selector(download:) callTimes: %d", callTimes]);

    NSArray *callArgs = [UADownloadManager getCallArgs:@selector(download:)];
    for (int i=0 ; i<expectProductsCount ; i++) {
        UAProduct *expectProduct = [expectProducts objectForKey:[allProductIDs objectAtIndex:i]];
        UADownloadContent *content = [[callArgs objectAtIndex:i] objectAtIndex:0];
        UAProduct *product = (UAProduct*)content.userInfo;
        GHAssertEquals(expectProduct, product, @"Test resume pending products failed. downloading content is not the expect product");
    }
}

- (void)testResumeWhenNoPendingProducts {
    NSDictionary *expectProducts = [[NSDictionary alloc] init];
    [self _testResumePendingProducts:expectProducts];
    [expectProducts release];
}

- (void)_makeProduct:(NSString*)pId putIntoDict:(NSMutableDictionary*)pDict {
    UAProduct *p = [UAProduct productFromDictionary:
                    [NSDictionary dictionaryWithObjectsAndKeys:pId, @"product_id", nil]];
    [pDict setObject:p forKey:pId];
}

- (void)testResumePendingProducts {
    NSMutableDictionary *expectProducts = [[NSMutableDictionary alloc] init];
    [self _makeProduct:@"p1" putIntoDict:expectProducts];
    [self _makeProduct:@"p2" putIntoDict:expectProducts];
    [self _makeProduct:@"p3" putIntoDict:expectProducts];

    [self _testResumePendingProducts:expectProducts];

    [expectProducts release];
}

@end

@implementation UADownloadManager(Mocked)
- (void)record_call_download:(UADownloadContent*)content {
    [[self class] recordCallSelector:@selector(download:)
                            withArgs:[NSArray arrayWithObject:content]];
}
- (NSArray*)nothing_allDownloadingContents {
    return [NSArray array];
}
@end

@implementation UAStoreFrontDownloadManager(Mocked)
- (void)fake_loadPendingProducts {
    NSDictionary *value = (NSDictionary *)[UATestGlobal shared].value;
    pendingProducts = [[value objectForKey:@"products"] retain];
}
- (void)record_call_and_continue_resumePendingProducts {
    [[self class] recordCallSelector:@selector(resumePendingProducts)
                            withArgs:nil];
    [self record_call_and_continue_resumePendingProducts];
    
    NSMutableDictionary *value = (NSMutableDictionary*)[UATestGlobal shared].value;
    [value setObject:[NSNumber numberWithInt:0] forKey:@"resumePendingProductsFinished"];
}
@end
