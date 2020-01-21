/* Copyright Airship and Contributors */

#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonCrypto.h>

#import "UAAccengageUtils.h"

@interface AirshipAccengageUtilsTest : XCTestCase

@end

@implementation AirshipAccengageUtilsTest

/**
 * Helper method for testing decryption.
 */
- (NSData *)encryptData:(NSData *)data key:(NSString *)key {
    if (!data || ![data isKindOfClass:[NSData class]]) {
        return nil;
    }

    // 'key' should be 32 bytes for AES256, will be null-padded otherwise
    char keyPtr[kCCKeySizeAES256+1]; // room for terminator (unused)
    bzero(keyPtr, sizeof(keyPtr)); // fill with zeroes (for padding)

    // fetch key data
    [key getCString:keyPtr maxLength:sizeof(keyPtr) encoding:NSUTF8StringEncoding];

    NSUInteger dataLength = [data length];

    //For block ciphers, the output size will always be less than or
    //equal to the input size plus the size of one block.
    //That's why we need to add the size of one block here
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);

    size_t numBytesDecrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128, kCCOptionPKCS7Padding,
                                          keyPtr, kCCKeySizeAES256, NULL, [data bytes], dataLength,
                                          buffer, bufferSize, &numBytesDecrypted);

    if (cryptStatus == kCCSuccess) {
        //the returned NSData takes ownership of the buffer and will free it on deallocation
        return [NSData dataWithBytesNoCopy:buffer length:numBytesDecrypted];
    }

    free(buffer); //free the buffer;
    return nil;
}

- (void)testDecryptData {
    NSData *stringData = [@"AnyData" dataUsingEncoding:NSUTF8StringEncoding];

    NSData *encryptedData = [self encryptData:stringData key:@"key"];
    XCTAssertNotNil(encryptedData, @"The encoded data should not be nil");
    
    NSData *unencryptedData = [UAAccengageUtils decryptData:encryptedData key:@"key"];
    XCTAssertNotNil(unencryptedData, @"An error occured when trying to decrypt data");

    XCTAssertEqualObjects(stringData, unencryptedData, @"String data and unencrypted data should match");
}

@end
