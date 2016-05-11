/*
 Copyright 2009-2016 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
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

//  Created by Mokhlas Hussein (iMokhles) on 08/04/16.
//


#import "NSURLConnection+Blocks.h"

@implementation NSURLConnection (NSURLConnection_Blocks)

static CompletionBlock _completionBlock;
static FailBlock _failBlock;
static CleanBlock _cleanBlock;
static NSMutableData *webData;
static NSInteger responseCode;

#pragma mark - Public Methods

+ (NSURLConnection*)connectionWithRequest:(NSURLRequest*)request onCompletion:(CompletionBlock)completionBlock onFail:(FailBlock)failBlock
{
    _cleanBlock = [^{
        _failBlock = nil;
        _completionBlock = nil;
        _cleanBlock = nil;
        webData = nil;
    } copy];
    
    _completionBlock = nil;
    _failBlock = nil;
    
    _completionBlock = [completionBlock copy];
    _failBlock = [failBlock copy];
    
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:[self class]];
    
    return connection;
}

#pragma mark - NSURLConnectionDelegate Implementation

+ (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (_failBlock)
    {
        _failBlock(error, responseCode);
    }
    
    if (_cleanBlock)
    {
        _cleanBlock();
    }
}

+ (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (_completionBlock)
    {
        _completionBlock([NSData dataWithData:webData], responseCode);
    }
    
    if (_cleanBlock)
    {
        _cleanBlock();
    }

}

+ (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{    
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    responseCode = [httpResponse statusCode];
    
    webData = [NSMutableData dataWithLength:1024];
	[webData setLength: 0];
}

+ (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[webData appendData:data];
}

@end
