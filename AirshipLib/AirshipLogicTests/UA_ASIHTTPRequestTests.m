/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
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
#import "UA_ASIHTTPRequest.h"
#import <SenTestingKit/SenTestingKit.h>
#import <OCMock/OCMock.h>
#import <OCMock/OCMConstraint.h>


@interface UA_ASIHTTPRequestTests : SenTestCase
@end


@implementation UA_ASIHTTPRequestTests
/*
 This is not a fully functional test (it only does a single POST), however it should be sufficient
 ASI doesn't built the headers until the request has actually entered it's run. There is s single web 
 request to Heroku's echo service, if it becomes too noisy or slow, pull it. */
- (void)testEmptyPayloadWithPutPostRequestHasContentLength {
    UA_ASIHTTPRequest *request = [UA_ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://rest-test.heroku.com"]];
    [request setRequestMethod:@"PUT"];
    NSString *contentLength = @"Content-Length";
    // Heroku doesn't handle PUT requests, so just buiild the body.
    [request buildPostBody];
    NSLog(@"status code %i", request.responseStatusCode);
    STAssertNotNil(request.requestHeaders, @"Request headers need to exist for the purpose of this test");
    STAssertNil(request.postBody, @"Post body should be nil");
    STAssertTrue([[request.requestHeaders valueForKey:contentLength] intValue] == 0, @"Content-Length should be 0");
    request = [UA_ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://rest-test.heroku.com"]];
    [request setRequestMethod:@"POST"];
    [request startSynchronous];
    STAssertNotNil(request.requestHeaders, @"Request headers need to exist for the purpose of this test");
    STAssertNil(request.postBody, @"Post body should be nil");
    STAssertTrue([[request.requestHeaders valueForKey:contentLength] intValue] == 0, @"Content-Length should be 0");
    // This should return an 200
    STAssertTrue(request.responseStatusCode == 200, @"Response from Heroku should be 200");
}

@end
