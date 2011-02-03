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

#import "UAInbox.h"

@class UAInboxMessageList;
@class UA_ASIHTTPRequest;

@interface UAInboxMessage : NSObject {
    NSString* messageID;
    NSURL* messageBodyURL;
    NSURL* messageURL;
    BOOL unread;
    NSDate* messageSent;
    NSString* title;
    NSDictionary* extra;
    UAInboxMessageList* inbox;
}


// Supported methods
/******************************************************************************/
- (id)initWithDict:(NSDictionary*)message inbox:(UAInboxMessageList*)inbox;
- (BOOL)markAsRead;
+ (void)performJSDelegate:(UIWebView*)webView url:(NSURL *)url;

@property (nonatomic, retain) NSString* messageID;
@property (nonatomic, retain) NSURL* messageBodyURL;
@property (nonatomic, retain) NSURL* messageURL;
@property (assign) BOOL unread;
@property (nonatomic, retain) NSDate* messageSent;
@property (nonatomic, retain) NSString* title;
@property (nonatomic, retain) NSDictionary* extra;
@property (assign) UAInboxMessageList* inbox;

-(NSString*)description;

@end
