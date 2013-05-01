
#import <Foundation/Foundation.h>
#import "UADeviceRegistrationData.h"
#import "UAHTTPRequestEngine.h"

typedef void (^UADeviceAPIClientSuccessBlock)(void);
typedef void (^UADeviceAPIClientFailureBlock)(UAHTTPRequest *request);

/**
 * A high level abstraction for performing Device API registration and unregistration.
 */
@interface UADeviceAPIClient : NSObject

/**
 * Register the device.
 * 
 * @param registrationData An instance of UADeviceRegistrationData.
 * @param onSuccess A UADeviceAPIClientSuccessBlock that will be called if the registration was successful.
 * @param onFailure A UADeviceAPIClientFailureBlock that will be called if the registration was unsuccessful.
 * @param forcefully If NO, the client will cache previous and pending registrations, ignoring duplicates.
 *
 */
- (void)registerWithData:(UADeviceRegistrationData *)registrationData
               onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
               onFailure:(UADeviceAPIClientFailureBlock)failureBlock
              forcefully:(BOOL)forcefully;

/**
 * Unregister the device.
 *
 * @param registrationData An instance of UADeviceRegistrationData.
 * @param onSuccess A UADeviceAPIClientSuccessBlock that will be called if the unregistration was successful.
 * @param onFailure A UADeviceAPIClientFailureBlock that will be called if the unregistration was unsuccessful.
 * @param forcefully If NO, the client will cache previous and pending registrations, ignoring duplicates.
 *
 */
- (void)unregisterWithData:(UADeviceRegistrationData *)registrationData
                 onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
                 onFailure:(UADeviceAPIClientFailureBlock)failureBlock
                forcefully:(BOOL)forcefully;

/**
 * Register the device.
 *
 * @param registrationData An instance of UADeviceRegistrationData.
 * @param onSuccess A UADeviceAPIClientSuccessBlock that will be called if the registration was successful.
 * @param onFailure A UADeviceAPIClientFailureBlock that will be called if the registration failed.
 *
 * Previous and pending registration data will be cached, and duplicates will be ignored.
 */
- (void)registerWithData:(UADeviceRegistrationData *)registrationData
               onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
               onFailure:(UADeviceAPIClientFailureBlock)failureBlock;


/**
 * Unregister the device.
 *
 * @param registrationData An instance of UADeviceRegistrationData.
 * @param onSuccess A UADeviceAPIClientSuccessBlock that will be called if the unregistration was successful.
 * @param onFailure A UADeviceAPIClientFailureBlock that will be called if the unregistration was unsuccessful.
 *
 * Previous and pending registration data will be cached, and duplicates will be ignored.
 */
- (void)unregisterWithData:(UADeviceRegistrationData *)registrationData
                 onSuccess:(UADeviceAPIClientSuccessBlock)successBlock
                 onFailure:(UADeviceAPIClientFailureBlock)failureBlock;

/**
 * Indicates whether the client should attempt to automatically retry HTTP connections under recoverable conditions
 * (5xx status codes, reachability errors, etc). In this case, the client will perform exponential backoff and schedule
 * reconnections accordingly before calling back with a success or failure.  Defaults to `YES`.
 */
@property(nonatomic, assign) BOOL shouldRetryOnConnectionError;

@end
