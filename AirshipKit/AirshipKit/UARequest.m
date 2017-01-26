/*
 Copyright 2009-2017 Urban Airship Inc. All rights reserved.

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

#import <zlib.h>

#import "UARequest+Internal.h"
#import "UAirship.h"
#import "UADisposable.h"
#import "UAConfig.h"
#import "UADelayOperation+Internal.h"

@interface UARequestBuilder()
@property (nonatomic, strong) NSMutableDictionary *headers;
@end
@implementation UARequestBuilder

- (instancetype)init {
    self = [super init];

    if (self) {
        self.headers = [NSMutableDictionary dictionary];
    }

    return self;
}

- (void)setValue:(id)value forHeader:(NSString *)header {
    [self.headers setValue:value forKey:header];
}

@end

@interface UARequest()
@property (nonatomic, copy) NSString *method;
@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, copy) NSDictionary *headers;
@property (nonatomic, copy, nullable) NSData *body;
@end

@implementation UARequest

- (instancetype)initWithBuilder:(UARequestBuilder *)builder {
    self = [super init];

    if (self) {
        self.method = builder.method;
        self.URL = builder.URL;


        NSMutableDictionary *headers = [NSMutableDictionary dictionary];

        // Basic auth
        if (builder.username && builder.password) {
            NSString *credentials = [NSString stringWithFormat:@"%@:%@", builder.username, builder.password];
            NSData *encodedCredentials = [credentials dataUsingEncoding:NSUTF8StringEncoding];
            NSString *authoriazationValue = [NSString stringWithFormat: @"Basic %@",[encodedCredentials base64EncodedStringWithOptions:0]];
            [headers setValue:authoriazationValue forKey:@"Authorization"];
        }

        // Additional headers
        if (builder.headers) {
            [headers addEntriesFromDictionary:builder.headers];
        }

        if (builder.body) {
            if (builder.compressBody) {
                self.body = [UARequest gzipCompress:builder.body];
                headers[@"Content-Encoding"] = @"gzip";
            } else {
                self.body = builder.body;
            }
        }


        self.headers = headers;
    }

    return self;
}

+ (instancetype)requestWithBuilderBlock:(void(^)(UARequestBuilder *builder))builderBlock {
    UARequestBuilder *builder = [[UARequestBuilder alloc] init];
    builder.compressBody = NO;

    if (builderBlock) {
        builderBlock(builder);
    }

    return [[UARequest alloc] initWithBuilder:builder];
}

+ (NSData *)gzipCompress:(NSData *)uncompressedData {

    if ([uncompressedData length] == 0) {
        return nil;
    }

    z_stream strm;

    NSUInteger chunkSize = 32768;// 32K chunks

    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.total_out = 0;
    strm.next_in=(Bytef *)[uncompressedData bytes];
    strm.avail_in = (uInt)[uncompressedData length];

    if (deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, (15+16), 8, Z_DEFAULT_STRATEGY) != Z_OK) {
        return nil;
    }

    int status;
    NSMutableData *compressed = [NSMutableData dataWithLength:chunkSize];
    do {

        if (strm.total_out >= [compressed length]) {
            [compressed increaseLengthBy:chunkSize];
        }

        strm.next_out = [compressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([compressed length] - strm.total_out);

        status = deflate(&strm, Z_FINISH);

        if (status == Z_STREAM_ERROR) {
            //error - bail completely
            deflateEnd(&strm);
            return nil;
        }

    } while (strm.avail_out == 0);

    deflateEnd(&strm);

    [compressed setLength: strm.total_out];
    
    return compressed;
}

@end
