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

#import "UAAnalyticsSendIfNeededTest.h"
#import "UAUtils.h"

@implementation UAAnalyticsSendIfNeededTest

- (void)setUpClass {
    [self mock:[UAAnalytics class] method:@selector(sendImpl) withMethod:@selector(sendImplMocked)];
    [self mock:[UAAnalytics class] method:@selector(initSession) withMethod:@selector(initSessionMocked)];
    [self mock:[UAEvent class] method:@selector(getEstimatedSize) withMethod:@selector(getEstimateSizeMocked)];
    [self mock:[UAAnalyticsDBManager class] method:@selector(addEvent:withSession:) withMethod:@selector(addEventMocked:withSession:)];
    [self mock:[UAAnalyticsDBManager class] method:@selector(deleteOldestSession) withMethod:@selector(deleteOldestSessionMocked)];
}

- (void)setUp {
    [[UAAnalyticsDBManager shared] resetDB];
    analytics = [[UAAnalytics alloc] initWithOptions:nil];
    [analytics setBatchInterval:0];
}

- (void)tearDown {
    [UAAnalytics removeAllCalls];
    [UAAnalyticsDBManager removeAllCalls];
    [analytics release];
}

- (void)tearDownClass {
}

- (void)testSendBatchSize {
    // test1: should not send
    int size = analytics.x_ua_max_batch - 1;
    UAEventAppInit *event = [UAEvent eventWithContext:nil];
    [analytics.session setObject:[NSString stringWithFormat:@"%d", size] forKey:@"event_size"];
    [analytics addEvent:event];

    NSArray *calls = [UAAnalytics getCalls:@selector(sendImpl)];
    int result = (calls.count == 0);
    GHAssertTrue(result, @"Should invoke [UAAnalytics sendImpl:] 0 times!");

    // test 2: should send
    size = 1;
    [analytics.session setObject:[NSString stringWithFormat:@"%d", size] forKey:@"event_size"];
    [analytics addEvent:event];

    calls = [UAAnalytics getCalls:@selector(sendImpl)];
    result = (calls.count == 1);
    GHAssertTrue(result, @"Should invoke [UAAnalytics sendImpl:] 1 times!");
}

- (void)testSendTime {
    // test1: should not send
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970] - [analytics x_ua_max_wait] + 0.1;
    UAEventAppInit *event = [UAEvent eventWithContext:nil];
    [event setTimeMocked:[NSString stringWithFormat:@"%f", time]];
    [analytics addEvent:event];

    NSArray *calls = [UAAnalytics getCalls:@selector(sendImpl)];
    int result = (calls.count == 0);
    GHAssertTrue(result, @"Should invoke [UAAnalytics sendImpl:] 0 times!");

    // test 2: should send
    [[UAAnalyticsDBManager shared] resetDB];
    time = [[NSDate date] timeIntervalSince1970] - [analytics x_ua_max_wait] - 0.1;
    [event setTimeMocked:[NSString stringWithFormat:@"%f", time]];
    [analytics addEvent:event];

    calls = [UAAnalytics getCalls:@selector(sendImpl)];
    result = (calls.count == 1);
    GHAssertTrue(result, @"Should invoke [UAAnalytics sendImpl:] 1 times!");
}

- (void)testDeleteSize {
    // test1: should not delete
    int size = analytics.x_ua_max_total/10;
    UAEventAppInit *event = [UAEvent eventWithContext:nil];
    [analytics.session setObject:[NSString stringWithFormat:@"%d", size] forKey:@"event_size"];
    for (int i=0; i<10; i++) {
        [analytics addEvent:event];
    }
    NSArray *calls = [UAAnalyticsDBManager getCalls:@selector(deleteOldestSession)];
    int result = (calls.count == 0);
    GHAssertTrue(result, @"Should invoke [[UAAnalyticsDBManager shared] deleteOldestSession] 0 times!");

    // test 2: should delete
    [analytics addEvent:event];
    calls = [UAAnalyticsDBManager getCalls:@selector(deleteOldestSession)];
    result = (calls.count == 1);
    GHAssertTrue(result, @"Should invoke [[UAAnalyticsDBManager shared] deleteOldestSession] 1 times!");
}

- (BOOL)checkCalls {
    NSArray *calls = [UAAnalytics getCalls:@selector(sendImpl)];
    if (calls.count == 2)
        return YES;
    else
        return NO;
}

- (void)testSendInterval {
    [analytics setBatchInterval:1];
    [analytics resetLastSendTimeAndOldestEvent];

    UAEventAppInit *event = [UAEvent eventWithContext:nil];
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970] - (NSTimeInterval)analytics.x_ua_max_wait - 0.1;
    [event setTimeMocked:[NSString stringWithFormat:@"%f", time]];
    [analytics addEvent:event];
    [analytics addEvent:event];
    [analytics addEvent:event];
    NSArray *calls = [UAAnalytics getCalls:@selector(sendImpl)];
    int result = (calls.count == 1);
    GHAssertTrue(result, @"Should invoke [UAAnalytics sendImpl:] 1 times! calls.count=%d", calls.count);

    [self spinRunThreadWithTimeOut:1 finishedCheckFunc:@selector(checkCalls) processingString:@"Waiting for resend again..."];
    calls = [UAAnalytics getCalls:@selector(sendImpl)];
    result = (calls.count == 2);
    GHAssertTrue(result, @"Should invoke [UAAnalytics sendImpl:] 2 times! calls.count=%d", calls.count);
}

@end

@implementation UAAnalytics(Mocked)

- (void)resetLastSendTimeAndOldestEvent {
    RELEASE_SAFELY(lastSendTime);
    oldestEventTime = 0;
}

- (void)initSessionMocked {
    RELEASE_SAFELY(session);
    session = [[NSMutableDictionary alloc] init];
    [session setObject:@"iphone4.1" forKey:@"device_version"];
    [session setObject:@"1.0" forKey:@"airship_version"];
    [session setObject:[UAUtils UUID] forKey:@"session_id"];
    [session setObject:@"100" forKey:@"event_size"];
}

- (void)setBatchInterval:(int)value {
    x_ua_min_batch_interval = value;
}

- (void)sendImplMocked {
    [[self class] recordCallSelector:@selector(sendImpl) withArgs:nil];
}

@end

@implementation UAEvent(Mocked)

- (void)setTimeMocked:(NSString*)t {
    RELEASE_SAFELY(time);
    time = [t retain];
}

- (int)getEstimateSizeMocked {
    return [[(NSDictionary*)[UATestGlobal shared].value objectForKey:@"event_size"] intValue];
}

@end


@implementation UAAnalyticsDBManager(Mocked)

- (void)addEventMocked:(UAEvent *)event withSession:(NSDictionary *)session {
    [db executeUpdate:@"INSERT INTO analytics (type, event_id, time, data, session_id, event_size) VALUES (?, ?, ?, ?, ?, ?)",
     [event getType],
     event.event_id,
     event.time,
     event.data,
     [session objectForKey:@"device_version"],
     [session objectForKey:@"airship_version"],
     [session objectForKey:@"session_id"],
     [session objectForKey:@"event_size"]];
    [UATestGlobal shared].value = session;
}

- (void)deleteOldestSessionMocked {
    [[self class] recordCallSelector:@selector(deleteOldestSession) withArgs:nil];
    [[UAAnalyticsDBManager shared] resetDB];
}

@end

