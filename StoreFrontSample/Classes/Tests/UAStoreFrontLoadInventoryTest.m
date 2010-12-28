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

#import "UAStoreFrontLoadInventoryTest.h"
#import "UAStoreFront.h"
#import "UAInventory.h"

@implementation UAStoreFrontLoadInventoryTest
UAInventory *inventory;

- (BOOL)shouldRunOnMainThread {
    return YES;
}

- (void)tearDownClass {
    [[UAStoreFront shared] forceRelease];
}

- (void)setUp {
    inventory = [[UAStoreFront shared].inventory retain];
}

- (void)tearDown {
    [inventory release];
}

#pragma mark -
#pragma mark Test load inventory

- (BOOL)checkInventoryLoadFinished {
    return inventory.status == UAInventoryStatusLoaded ||
    inventory.status == UAInventoryStatusFailed;
}

- (NetworkStatus)currentNetworkStatus {
    NetworkStatus status = [[UA_Reachability reachabilityForInternetConnection] currentReachabilityStatus];
    switch (status) {
        case NotReachable:
            GHTestLog(@"Device networkStatus: NotReachable");
            break;
        case ReachableViaWWAN:
            GHTestLog(@"Device networkStatus: ReachableViaWWAN");
            break;
        case ReachableViaWiFi:
            GHTestLog(@"Device networkStatus: ReachableViaWiFi");
            break;
    }
    return status;
}

- (void)testLoadInventory {
    [self mock:[UAInventory class] method:@selector(hostReachStatusChanged:) withMethod:@selector(do_nothing_hostReachStatusChanged:)];
    GHTestLog(@"Network status at before loading inventory: ");
    NetworkStatus networkStatus = [self currentNetworkStatus];
    [UAStoreFront loadInventory];
    GHAssertEquals(inventory.status, UAInventoryStatusDownloading, @"Begin Loading Error. :-(");
    
    [self spinRunThreadWithTimeOut:60
                 finishedCheckFunc:@selector(checkInventoryLoadFinished)
                  processingString:@"Waiting for inventory to load..."];
    GHTestLog(@"Network status at inventory loaded: ");
    NetworkStatus networkStatusLoaded = [self currentNetworkStatus];
    
    if (networkStatus == networkStatusLoaded) {
        GHAssertEquals(inventory.status, UAInventoryStatusLoaded, @"Test load inventory failed!");
    } else {
        GHTestLog(@"Network reachability has changed, please retest.");
    }
}

- (void)testLoadInventoryWithError {
    [self mock:[UAInventory class] method:@selector(reloadInventory) withMethod:@selector(do_not_reload_inventory)];
    [self mock:[UA_ASIHTTPRequest class] method:@selector(requestFinished) withMethod:@selector(return_connection_fail_requestFinished)];
    [UAStoreFront loadInventory];
    GHAssertEquals(inventory.status, UAInventoryStatusDownloading, @"Begin Loading Error. :-(");
    [self spinRunThreadWithTimeOut:60
                 finishedCheckFunc:@selector(checkInventoryLoadFinished)
                  processingString:@"Waiting for inventory to load..."];
    GHAssertEquals(inventory.status, UAInventoryStatusFailed, @"Test load inventory failed!");
}

@end

#pragma mark -

@implementation UA_ASIHTTPRequest (Mocked)
- (void)return_connection_fail_requestFinished {
    [self failWithError:[NSError errorWithDomain:UA_NetworkRequestErrorDomain 
                                            code:ASIConnectionFailureErrorType 
                                        userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The request connection failure",NSLocalizedDescriptionKey,nil]]];
    [self performSelector:@selector(reportFailure)];
}
@end




