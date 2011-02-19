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

#import "UAAnalyticsSendTest.h"
#import "UA_SBJsonParser.h"
#import "UAUtils.h"

@implementation UAAnalyticsSendTest

- (void)setUpClass {
    [self mock:[UAHTTPConnection class] method:@selector(start) withMethod:@selector(startMocked)];
    analytics = [[UAAnalytics alloc] initWithOptions:nil];
}

- (void)setUp {
    [[UAAnalyticsDBManager shared] resetDB];
}

- (void)tearDown {
    [UAAnalytics removeAllCalls];
    [UAAnalyticsDBManager removeAllCalls];
}

- (void)tearDownClass {
    [analytics release];
}

#define TEST_EVENT_MAX  100
NSString *testSystemVersion = @"2.0";
NSString *testAirshipVersion = @"1.0.0";

- (void)addTestEvents {
    // Note: The parameter8 is event size, can't be 0.
    for (int i=1; i<=TEST_EVENT_MAX; i++) {
        [[UAAnalyticsDBManager shared].db executeUpdate:@"INSERT INTO analytics (type, event_id, time, data, session_id, event_size) VALUES (?, ?, ?, ?, ?, ?)",
         [NSString stringWithFormat:@"type%d", i],
         [NSString stringWithFormat:@"id%d", i],
         [NSString stringWithFormat:@"%d", i],
         [NSDictionary dictionary],
         testSystemVersion,
         testAirshipVersion,
         @"sessionID",
         [NSString stringWithFormat:@"%d", i]];
    }
}

- (void)_testEvents:(UAHTTPRequest*)request {
    UA_SBJsonParser *parser = [UA_SBJsonParser new];
    NSArray *events = [parser objectWithString:[NSString stringWithFormat:@"%s", [request.postData bytes]]];
    NSDictionary *event;

    NSDictionary *headers = request.headers;
    NSDictionary *eventData = nil;
    if (![[headers objectForKey:@"X-UA-Library"] isEqual:testAirshipVersion])
        GHFail(@"X-UA-Library error.");
    if (![[headers objectForKey:@"X-UA-Device-Model"] isEqual:[UAUtils deviceModelName]])
        GHFail(@"X-UA-Device-Model error.");
    if (![[headers objectForKey:@"X-UA-Device-Family"] isEqual:[UIDevice currentDevice].systemName])
        GHFail(@"X-UA-Device-Family error.");

    for (int i=1; i<=TEST_EVENT_MAX; i++) {
        event = [events objectAtIndex:(i - 1)];
        eventData = (NSDictionary*)[event objectForKey:@"data"];
        if (![[NSString stringWithFormat:@"type%d", i] isEqual:[event objectForKey:@"type"]])
            GHFail(@"package error.");
        if (![[NSString stringWithFormat:@"id%d", i] isEqual:[event objectForKey:@"event_id"]])
            GHFail(@"package error.");
        if (![[NSString stringWithFormat:@"%d", i] isEqual:[event objectForKey:@"time"]])
            GHFail(@"package error.");
        if (![@"sessionID" isEqual:[eventData objectForKey:@"session_id"]])
            GHFail(@"package error.");
        if (![[NSString stringWithFormat:@"%d", i] isEqual:[eventData objectForKey:@"event_size"]])
            GHFail(@"package error.");
    }
    [parser release];
}

- (void)testSendImpl {
    [self addTestEvents];
    [analytics performSelector:@selector(sendImpl)];
    [self _testEvents:[[UATestGlobal shared] value]];
}



@end

@implementation UAAnalyticsDBManager(Mocked)

- (UASQLite *)db {
    return db;
}

@end


@implementation UAHTTPConnection(Mocked)

- (BOOL)startMocked {
    [[self class] recordCallSelector:@selector(start) withArgs:nil];
    [UATestGlobal shared].value = (id)request;
    return YES;
}

@end

