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

#import "UA_Base64.h"
#import <XCTest/XCTest.h>

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

@interface UABase64Test : XCTestCase
@end


@implementation UABase64Test

- (void)testBase64Encode {
    NSData *dataToEncode = [pleasure dataUsingEncoding:NSASCIIStringEncoding];
    NSString* encoded = UA_base64EncodedStringFromData(dataToEncode);
    XCTAssertTrue([encoded isEqualToString:pleasure64]);
    dataToEncode = [leasure dataUsingEncoding:NSASCIIStringEncoding];
    encoded = UA_base64EncodedStringFromData(dataToEncode);
    XCTAssertTrue([encoded isEqualToString:leasure64]);
    dataToEncode = [easure dataUsingEncoding:NSASCIIStringEncoding];
    encoded = UA_base64EncodedStringFromData(dataToEncode);
    XCTAssertTrue([encoded isEqualToString:easure64]);
}

- (void)testBase64Decode {
    NSData *decodedData = UA_dataFromBase64String(pleasure64);
    NSString *decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:pleasure]);
    decodedData = UA_dataFromBase64String(leasure64);
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:leasure]);
    decodedData = UA_dataFromBase64String(easure64);
    decodedString = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([decodedString isEqualToString:easure]);
}

- (void)testBase64DecodeInvalidString {
    XCTAssertNoThrow(UA_dataFromBase64String(@"."));
    XCTAssertNoThrow(UA_dataFromBase64String(@" "));
    XCTAssertNoThrow(UA_dataFromBase64String(nil));
}

//void *UA_NewBase64Decode(
//                         const char *inputBuffer,
//                         size_t length,
//                         size_t *outputLength);
//
//char *UA_NewBase64Encode(
//                         const void *inputBuffer,
//                         size_t length,
//                         bool separateLines,
//                         size_t *outputLength);

- (void)testArbitraryUnprintableData {
    // Test encoding
    Byte null = 0x00;
    Byte beep = 0x07;
    Byte unit_separator = 0x1F;
    Byte data[] = {null, beep, unit_separator};
    size_t outputLength;
    char *outputBuffer = UA_NewBase64Encode(data, 3*sizeof(Byte), NO, &outputLength);
    char *bufferShouldBe = "AAcf";
    for (int i=0; i<4; i++) {
        XCTAssertTrue(outputBuffer[i] == bufferShouldBe[i], @"Encoding non printable failed");
    }
    // Test decoding
    // This buffer needs to be freed at the end of the test
    void *buffer = UA_NewBase64Decode(bufferShouldBe, 4*sizeof(char), &outputLength);
    Byte *byteBuffer = (Byte*)buffer;
    for (size_t i = 0; i < outputLength; i++) {
        XCTAssertTrue(data[i] == byteBuffer[i], @"Decoding non printable failed");
    }
    free(buffer);
    // Test wrapper functions
    // Test encoding
    NSData *encodedUprintableData = [NSData dataWithBytes:data length:3*sizeof(Byte)];
    NSString *encodedUprintableDataString = UA_base64EncodedStringFromData(encodedUprintableData);
    NSString *encodedChars = [NSString stringWithCString:bufferShouldBe encoding:NSASCIIStringEncoding];
    XCTAssertTrue([encodedUprintableDataString isEqualToString:encodedChars]);
    // Test decoding 
    NSData *decodedData = UA_dataFromBase64String(encodedChars);
//    STAssertTrue([decodedData length] == 3, @"NSData reporting unexpected test data length in base64 decoding");
//    Byte decodedByteData[[decodedData length]];
//    [decodedData getBytes:decodedByteData length:[decodedData length]];
//    for (size_t i = 0; i< [decodedData length]; i++) {
//        STAssertTrue(decodedByteData[i] == data[i], @"Decoding non printable using ObjC wrapper failed");
//    }
    NSString *stringFromDecodedData = [[NSString alloc] initWithData:decodedData encoding:NSASCIIStringEncoding];
    XCTAssertTrue([stringFromDecodedData length] == 3, @"String from decoded data is the wrong lenght");
    // things can get wonky, characterAtIndex returns a unichar (unsigned short) which is getting downcast to a byte
    for (int i=0; i < [stringFromDecodedData length]; i++) {
        XCTAssertTrue((Byte)[stringFromDecodedData characterAtIndex:i] == data[i], @"Creating NSString from decoded NSData failed");
    }
    
    
}

@end
