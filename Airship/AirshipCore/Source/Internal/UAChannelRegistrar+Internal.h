/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

#import "UAChannelRegistrationPayload.h"
#import "UARuntimeConfig.h"
#import "UADate.h"
#import "UADispatcher.h"
#import "UATaskManager.h"

@class UAPreferenceDataStore;
@class UAChannelAPIClient;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const UAChannelRegistrarChannelIDKey;

/**
 * The UAChannelRegistrarDelegate protocol for registration events.
 */
@protocol UAChannelRegistrarDelegate <NSObject>

///---------------------------------------------------------------------------------------
/// @name Required Channel Registrar Delegate Methods
///---------------------------------------------------------------------------------------
@required

/**
 * Get registration payload for current channel
 *
 * @note This method will be called on the main thread.
 *
 * @param completionHandler A completion handler which will be passed the created registration payload.
 */
- (void)createChannelPayload:(void (^)(UAChannelRegistrationPayload *))completionHandler;
/**
 * Called when the channel registrar failed to register.
 */
- (void)registrationFailed;

/**
 * Called when the channel registrar successfully registered.
 */
- (void)registrationSucceeded;

/**
 * Called when the channel registrar creates a new channel.
 * @param channelID The channel ID string.
 * @param existing Boolean to indicate if the channel previously existed or not.
 */
- (void)channelCreated:(NSString *)channelID
              existing:(BOOL)existing;

@end

/**
* The UAChannelRegistrar class is responsible for device registrations.
*/
@interface UAChannelRegistrar : NSObject

///---------------------------------------------------------------------------------------
/// @name Channel Registrar Factory
///---------------------------------------------------------------------------------------

/**
 * Factory method to create a channel registrar.
 * @param config The Airship config.
 * @param dataStore The shared preference data store.
 * @return A new channel registrar instance.
 */
+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore;


///---------------------------------------------------------------------------------------
/// @name Channel Registrar Registration Management
///---------------------------------------------------------------------------------------

/**
 * Register the device with Airship.
 *
 * @note This method will execute asynchronously on the main thread.
 *
 * @param forcefully YES to force the registration.
 */
- (void)registerForcefully:(BOOL)forcefully;

/**
 * Performs a full channel registration.
 */
- (void)performFullRegistration;

///---------------------------------------------------------------------------------------
/// @name Channel Registrar Properties
///---------------------------------------------------------------------------------------
///

/**
 * The UAChannelRegistrarDelegate delegate.
 */
@property (nonatomic, weak, nullable) id<UAChannelRegistrarDelegate> delegate;

/**
 * The channel ID for this device.
 */
@property (nonatomic, copy, nullable, readonly) NSString *channelID;

///---------------------------------------------------------------------------------------
/// @name Channel Registrar Factory (for testing)
///---------------------------------------------------------------------------------------
/**
 * Factory method to create a channel registrar. (for testing)
 * @param config The Airship config.
 * @param dataStore The shared preference data store.
 * @param channelAPIClient The channel API client.
 * @param date The UADate object.
 * @param dispatcher The dispatcher to dispatch main queue blocks.
 * @param taskManager The task manager.
 * @return A new channel registrar instance.
 */
+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                          channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                                      date:(UADate *)date
                                dispatcher:(UADispatcher *)dispatcher
                               taskManager:(UATaskManager *)taskManager;

///---------------------------------------------------------------------------------------
/// @name Channel Registrar Properties (for testing)
///---------------------------------------------------------------------------------------

/**
 * The last successful payload that was registered.
 */
@property (nonatomic, strong, nullable, readonly) UAChannelRegistrationPayload *lastSuccessfulPayload;

/**
 * The date of the last successful update.
 */
@property (nonatomic, strong, nullable, readonly) NSDate *lastSuccessfulUpdateDate;

@end

NS_ASSUME_NONNULL_END

