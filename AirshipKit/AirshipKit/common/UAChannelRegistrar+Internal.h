/* Copyright Urban Airship and Contributors */

#import <UIKit/UIKit.h>

@class UAChannelRegistrationPayload;
@class UAChannelAPIClient;
@class UAConfig;
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
 * @param channelLocation The channel location string.
 * @param existing Boolean to indicate if the channel previously existed or not.
 */
- (void)channelCreated:(NSString *)channelID
       channelLocation:(NSString *)channelLocation
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
 * @param config The Urban Airship config.
 * @param dataStore The shared preference data store.
 * @param delegate The UAChannelRegistrarDelegate delegate.
 * @return A new channel registrar instance.
 */
+ (instancetype)channelRegistrarWithConfig:(UAConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                  delegate:(id<UAChannelRegistrarDelegate>)delegate;


///---------------------------------------------------------------------------------------
/// @name Channel Registrar Registration Management
///---------------------------------------------------------------------------------------

/**
 * Register the device with Urban Airship.
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
/**
 * The channel ID for this device.
 */
@property (nonatomic, copy, nullable, readonly) NSString *channelID;

///---------------------------------------------------------------------------------------
/// @name Channel Registrar Factory (for testing)
///---------------------------------------------------------------------------------------
/**
 * Factory method to create a channel registrar. (for testing)
 * @param config The Urban Airship config.
 * @param dataStore The shared preference data store.
 * @param delegate The UAChannelRegistrarDelegate delegate.
 * @param channelID The initial channel ID string.
 * @param channelLocation The initial channel location string.
 * @param channelAPIClient The channel API client.
 * @param date The UADate object.
 * @param dispatcher The dispatcher to dispatch main queue blocks.
 * @param application The application.
 * @return A new channel registrar instance.
 */
+ (instancetype)channelRegistrarWithConfig:(UAConfig *)config
                                 dataStore:(UAPreferenceDataStore *)dataStore
                                  delegate:(id<UAChannelRegistrarDelegate>)delegate
                                 channelID:(NSString *)channelID
                           channelLocation:(NSString *)channelLocation
                          channelAPIClient:(UAChannelAPIClient *)channelAPIClient
                                      date:(UADate *)date
                                dispatcher:(UADispatcher *)dispatcher
                               application:(UIApplication *)application;

///---------------------------------------------------------------------------------------
/// @name Channel Registrar Properties (for testing)
///---------------------------------------------------------------------------------------

/**
 * Channel location as a string.
 */
@property (nonatomic, copy, nullable, readonly) NSString *channelLocation;

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

