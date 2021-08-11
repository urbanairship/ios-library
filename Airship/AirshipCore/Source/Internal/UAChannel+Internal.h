/* Copyright Airship and Contributors */

#import "UAChannel.h"
#import "UAExtendableChannelRegistration.h"

@class UAChannelRegistrar;
@class UAChannelAudienceManager;
@class UADate;

extern NSString *const UAChannelTagsSettingsKey;

@interface UAChannel () <UAExtendableChannelRegistration>

/**
 * Allows disabling channel registration before a channel is created.  Channel registration will resume
 * when this flag is set to `YES`.
 *
 * Set this to `NO` to disable channel registration. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isChannelCreationEnabled) BOOL channelCreationEnabled;

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                       localeManager:(UALocaleManager *)localeManager
                      privacyManager:(UAPrivacyManager *)privacyManager;

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                    channelRegistrar:(UAChannelRegistrar *)channelRegistrar
                     audienceManager:(UAChannelAudienceManager *)audienceManager
                       localeManager:(UALocaleManager *)localeManager
                                date:(UADate *)date
                      privacyManager:(UAPrivacyManager *)privacyManager;

/**
 * Registers or updates the current registration with an API call. If push notifications are
 * not enabled, this unregisters the device token.
 *
 * Observe NSNotificationCenterEvents such as UAChannelCreatedEvent, UAChannelUpdatedEvent and UAChannelRegistrationFailedEvent
 * to receive success and failure callbacks.
 *
 * @param forcefully Tells the device api client to do any device api call forcefully.
 */
- (void)updateRegistrationForcefully:(BOOL)forcefully;


@end


