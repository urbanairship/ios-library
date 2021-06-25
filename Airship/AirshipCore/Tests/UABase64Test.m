/* Copyright Airship and Contributors */

#import "UABaseTest.h"
@import AirshipCore;

// Examples from Wikipedia page on base64 encoding
// http://en.wikipedia.org/wiki/Base64
// These test strings were encoded/decoded with Python 2.7.2 base64 lib to check for errors
// Note the period (.), it is part of the encoding, as well as the '=' sign, it is used
// for padding. 

//>>> one = base64.b64encode('pleasure.')
//>>> print(one)
//cGxlYXN1cmUu
//>>> one == 'cGxlYXN1cmUu'
//True
//>>> one = base64.b64encode('leasure.')
//>>> one == 'bGVhc3VyZS4='
//True
//>>> one = base64.b64encode('easure.')
//>>> one == 'ZWFzdXJlLg=='
//True
//>>> 

NSString *pleasure = @"pleasure.";
NSString *pleasure64 = @"cGxlYXN1cmUu";

NSString *leasure = @"leasure.";
NSString *leasure64 = @"bGVhc3VyZS4=";

NSString *easure = @"easure.";
NSString *easure64 = @"ZWFzdXJlLg==";
NSString *easure64PartiallyPadded = @"ZWFzdXJlLg=";
NSString *easure64Unpadded = @"ZWFzdXJlLg";
NSString *easure64Newline = @"ZWFzdXJlLg\n";
NSString *easure64InterstitialNewline = @"ZWFzdXJlLg=\n=";

@interface UABase64Test : UABaseTest
@end


@implementation UABase64Test

- (void)testBase64Encode {
    NSData *dataToEncode = [pleasure dataUsingEncoding:NSASCIIStringEncoding];
    NSString* encoded = [UABase64 stringFromData:dataToEncode];
    XCTAssertTrue([encoded isEqualToString:pleasure64]);
    dataToEncode = [leasure dataUsingEncoding:NSASCIIStringEncoding];
    encoded = [UABase64 stringFromData:dataToEncode];
    XCTAssertTrue([encoded isEqualToString:leasure64]);
    dataToEncode = [easure dataUsingEncoding:NSASCIIStringEncoding];
    encoded = [UABase64 stringFromData:dataToEncode];
    XCTAssertTrue([encoded isEqualToString:easure64]);
}

- (void)testBase64Decode {
    NSData *decodedData = [UABase64 dataFromString:pleasure64];
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:pleasure]);

    decodedData = [UABase64 dataFromString:leasure64];
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:leasure]);

    decodedData = [UABase64 dataFromString:easure64];
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:easure]);

    decodedData = [UABase64 dataFromString:easure64PartiallyPadded];
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:easure]);

    decodedData = [UABase64 dataFromString:easure64Unpadded];
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:easure]);

    decodedData = [UABase64 dataFromString:easure64Newline];
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:easure]);

    decodedData = [UABase64 dataFromString:easure64InterstitialNewline];
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:easure]);
}

- (void)testBase64DecodeInvalidString {
    XCTAssertNoThrow([UABase64 dataFromString:@"."]);
    XCTAssertNoThrow([UABase64 dataFromString:@" "]);
    XCTAssertNoThrow([UABase64 dataFromString:nil]);
}

@end
