/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
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

#import <Foundation/Foundation.h>
#import <NewsstandKit/NewsstandKit.h>

#import "UAProductInventory.h"
#import "UASubscriptionManager.h"
#import "UAHTTPConnection.h"
#import "UADownloadContent.h"

/**
 * UANewsstandHelper is a fully contained helper class that processes
 * newsstand pushes, retrieves the download URL, downloads and unzips
 * your content.
 *
 * In addition to making code changes, the following items must be
 * added to your app's Info.plist file:
 *
 * To enable newsstand:
 *   <key>UINewsstandApp</key>
 *   <true/>
 *
 * To enable background downloads:
 *   <key>UIBackgroundModes</key>
 *   <array>
 *     <string>newsstand-content</string>
 *   </array>
 *
 * You must also register for Newsstand pushes by adding 
 * UIRemoteNotificationTypeNewsstandContentAvailability to your 
 * registerForRemoteNotificationTypes: call.
 *
 */
@interface UANewsstandHelper : NSObject<NSURLConnectionDownloadDelegate,
                                        UAHTTPConnectionDelegate,
                                        UASubscriptionManagerObserver,
                                        UAZipDownloadContentProtocol> {
@private
    NSString *contentIdentifier;
    UAHTTPConnection *connection;
}

@property (nonatomic, copy) NSString *contentIdentifier;

/**
 * Process a push notification dictionary and start the
 * newsstand download process if the push contains
 * a content-available item in the aps portion of the
 * payload.
 */
- (void)handleNewsstandPushInfo:(NSDictionary *)userInfo;

@end
