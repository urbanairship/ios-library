/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAChannelRegistrationPayload;
@class UAChannelAPIClient;
@class UARuntimeConfig;
@class UAPreferenceDataStore;
@class UADate;
@class UADispatcher;

NS_ASSUME_NONNULL_BEGIN

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
 * @param dispatcher The dispatcher to call the completion handler on.
 */
- (void)createChannelPayload:(void (^)(UAChannelRegistrationPayload *))completionHandler
                  dispatcher:(nullable UADispatcher *)dispatcher;

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
 * Cancels all pending and current requests.
 *
 * Note: This may or may not prevent the registration finished event and registration
 * delegate calls.
 */
- (void)cancelAllRequests;

/**
* Removes the existing channel and forces a registration to create a new one.
*/
- (void)resetChannel;

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
 * @param channelID The initial channel ID string.
 * @param channelAPIClient The channel API client.
 * @param date The UADate object.
 * @param dispatcher The dispatcher to dispatch main queue blocks.
 * @param application The application.
 * @return A new channel registrar instance.
 */
+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                 channelID:(NSString *)channelID
                          channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                                      date:(UADate *)date
                                dispatcher:(UADispatcher *)dispatcher
                               application:(UIApplication *)application;

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

