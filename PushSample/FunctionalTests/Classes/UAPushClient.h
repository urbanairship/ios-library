//
//  UAPushClient.h
//  PushSampleLib
//
//  Created by Jeff Towle on 6/3/13.
//
//

#import <Foundation/Foundation.h>

@class UAHTTPRequest;

@interface UAPushClient : NSObject

+ (void)sendAlert:(NSString *)alert toDeviceToken:(NSString *)deviceToken;
+ (void)sendAlert:(NSString *)alert toTag:(NSString *)tag;
+ (void)sendAlert:(NSString *)alert toAlias:(NSString *)alias;

+ (void)sendBroadcastAlert:(NSString *)alert;

// helpers
+ (void)sendAlertWithPayload:(NSDictionary *)payload;
+ (UAHTTPRequest *)pushRequestWithURLString:(NSString *)URL;

@end
