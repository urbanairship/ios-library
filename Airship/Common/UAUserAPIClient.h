
#import <Foundation/Foundation.h>
#import "UAUserData.h"
#import "UAHTTPConnection.h"

typedef void (^UAUserAPIClientCreateSuccessBlock)(UAUserData *data, NSString *deviceToken);
typedef void (^UAUserAPIClientUpdateSuccessBlock)(NSString *deviceToken);
typedef void (^UAUserAPIClientFailureBlock)(UAHTTPRequest *request);

@interface UAUserAPIClient : NSObject

- (void)createUserOnSuccess:(UAUserAPIClientCreateSuccessBlock)successBlock onFailure:(UAUserAPIClientFailureBlock)failureBlock;
- (void)updateDeviceToken:(NSString *)deviceToken forUsername:(NSString *)username onSuccess:(UAUserAPIClientUpdateSuccessBlock)successBlock onFailure:(UAUserAPIClientFailureBlock)failureBlock;

@end
