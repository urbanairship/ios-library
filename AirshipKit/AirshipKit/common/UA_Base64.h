/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

/** Returns an NSData object of decoded 64 bit values,
 could be turned into a byte array, or directly into a NSString 
 @param aString base 64 encoded NSString that needs to be decoded
 @return NSData object containing decoded data which can be converted 
 to a byte array or NSString, uses NSASCIIStringEncoding 
 */
NSData* UA_dataFromBase64String(NSString* aString);

/** Takes a byte array filled with ASCII encoded representation
 of data, for our purposes this is a NSString of the app key or 
 secret converted to an NSData object
 @param data NSData representation of a string that needs to be converted
    to base 64 encoding, expects NSASCIIStringEncoding
 @return NSString, base 64 encoded using NSASCIIStringEncoding
 */
NSString* UA_base64EncodedStringFromData(NSData* data);
