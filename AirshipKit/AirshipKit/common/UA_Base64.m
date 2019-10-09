/* Copyright Airship and Contributors */

#import "UA_Base64.h"
#import "UAGlobal.h"

//
// dataFromBase64String:
//
// Creates an NSData object containing the base64 decoded representation of
// the base64 string 'aString'
//
// Parameters:
//    aString - the base64 string to decode
//
// returns the autoreleased NSData representation of the base64 string
//
NSData* UA_dataFromBase64String(NSString *str) {
    if (str == nil) {
        UA_LERR(@"UA_Base64: Unable to create data with nil string.");
        return nil;
    }

    // Strip newlines
    str = [[str componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@""];
    // Strip pre-existing padding characters
    str = [str stringByReplacingOccurrencesOfString:@"=" withString:@""];

    // Must be a multiple of 4 characters post padding
    // For more information: https://tools.ietf.org/html/rfc4648#section-8
    switch ((str.length % 4)) {
         case 2:
             str = [str stringByAppendingString:@"=="];
             break;
         case 3:
             str = [str stringByAppendingString:@"="];
             break;
         default:
             break;
     }


    return [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
}


//
// base64EncodedString
//
// Creates an NSString object that contains the base 64 encoding of the
// receiver's data. Lines are broken at 64 characters long.
//
// returns an autoreleased NSString being the base 64 representation of the
//    receiver.
//
NSString* UA_base64EncodedStringFromData(NSData *data) {
    NSString *result = [[NSString alloc] initWithData:[data base64EncodedDataWithOptions:NSDataBase64Encoding64CharacterLineLength]
                                             encoding:NSASCIIStringEncoding];

    return result;
}
