
#import <Foundation/Foundation.h>
#import "UAUserData.h"
#import "UAHTTPConnection.h"

typedef void (^UAUserAPIClientCreateSuccessBlock)(UAUserData *data, NSDictionary *payload);
typedef void (^UAUserAPIClientUpdateSuccessBlock)();
typedef void (^UAUserAPIClientFailureBlock)(UAHTTPRequest *request);

/**
 * High level abstraction for the User API.
 */
@interface UAUserAPIClient : NSObject


 /**
 * Create a user.
 *
 * @param successBlock A UAUserAPIClientCreateSuccessBlock that will be called if user creation was successful.
 * @param failureBlock A UAUserAPIClientFailureBlock that will be called if user creation was unsuccessful.
 */
- (void)createUserWithChannelID:(NSString *)channelID
                    deviceToken:(NSString *)deviceToken
                      onSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock
                      onFailure:(UAUserAPIClientFailureBlock)failureBlock;

/**
 * Update a user's associated device token.
 *
 * @param deviceToken The specified device token to be updated.
 * @param username The specified user to update.
 * @param successBlock A UAUserAPIClientUpdateSuccessBlock that will be called if the update was successful.
 * @param failureBlock A UAUserAPIClientFailureBlock that will be called if the update was unsuccessful.
 */
- (void)updateUser:(NSString *)username
       deviceToken:(NSString *)deviceToken
         channelID:(NSString *)channelID
         onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock
         onFailure:(UAUserAPIClientFailureBlock)failureBlock;

@end
