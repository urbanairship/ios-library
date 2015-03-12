/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

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
#import "ASIHTTPRequest+UATest.h"

@implementation UA_ASIHTTPRequest (UATest)

#ifdef INBOX_TESTS

- (id)initWithURL:(NSURL *)newURL
{
    NSLog(@"Request initialized in UA_ASIHTTPRequest (UATest) category");
    self = [self init];
    [self setRequestMethod:@"GET"];

    [self setShouldAttemptPersistentConnection:YES];
    [self setPersistentConnectionTimeoutSeconds:60.0];
    [self setShouldPresentCredentialsBeforeChallenge:YES];
    [self setShouldRedirect:YES];
    [self setShowAccurateProgress:YES];
    [self setShouldResetProgressIndicators:YES];
    [self setAllowCompressedResponse:YES];
    [self setDefaultResponseEncoding:NSISOLatin1StringEncoding];
    [self setShouldPresentProxyAuthenticationDialog:YES];

    [self setTimeOutSeconds:[UA_ASIHTTPRequest defaultTimeOutSeconds]];
    [self setUseSessionPersistence:YES];
    [self setUseCookiePersistence:YES];

    // Do not validate ssl certificates for tests.  The Simulator fails to
    // accept valid certificate chains.
    [self setValidatesSecureCertificate:NO];

    [self setRequestCookies:[[[NSMutableArray alloc] init] autorelease]];
    [self setDidStartSelector:@selector(requestStarted:)];
    [self setDidFinishSelector:@selector(requestFinished:)];
    [self setDidFailSelector:@selector(requestFailed:)];
    [self setURL:newURL];

    // Set this directly, because we don't have access to the private setter
    cancelledLock = [[NSRecursiveLock alloc] init];

    return self;
}
#endif

@end
