
#import <Foundation/Foundation.h>
#import "UAUserData.h"
#import "UAHTTPConnection.h"

@class UAHTTPRequestEngine;

typedef void (^UAUserAPIClientCreateSuccessBlock)(UAUserData *data, NSDictionary *payload);
typedef void (^UAUserAPIClientUpdateSuccessBlock)();
typedef void (^UAUserAPIClientFailureBlock)(UAHTTPRequest *request);

/**
 * High level abstraction for the User API.
 */
@interface UAUserAPIClient : NSObject


/**
 * Factory method to create a UAUserAPIClient.
 */
+ (instancetype)client;


/**
 * Factory method to create a UAUserAPIClient.
 *
 * @param requestEngine The specified UAHTTPRequestEngine.
 */
+ (instancetype)clientWithRequestEngine:(UAHTTPRequestEngine *)requestEngine;

/**
 * Create a user.
 *
 * If the channel id is available, only it will be used.  If not, the device token
 * will be used.
 * 
 * @param deviceToken The user's device token.
 * @param channelID The user's channel ID.
 * @param successBlock A UAUserAPIClientCreateSuccessBlock that will be called if user creation was successful.
 * @param failureBlock A UAUserAPIClientFailureBlock that will be called if user creation was unsuccessful.
 */
- (void)createUserWithChannelID:(NSString *)channelID
                    deviceToken:(NSString *)deviceToken
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock;

/**
 * Update a user.
 *
 * If the channel id is available, it will add the channel and remove
 * the device token.  If only the device token is available it will add it to the user.
 *
 * @param username The specified user to update.
 * @param deviceToken The user's device token.
 * @param channelID The user's channel ID.
 * @param successBlock A UAUserAPIClientUpdateSuccessBlock that will be called if the update was successful.
 * @param failureBlock A UAUserAPIClientFailureBlock that will be called if the update was unsuccessful.
 */
- (void)updateUser:(NSString *)username
       deviceToken:(NSString *)deviceToken
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock;

@end
