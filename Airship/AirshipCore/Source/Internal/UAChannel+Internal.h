/* Copyright Airship and Contributors */

#import "UAChannel.h"
#import "UAChannelRegistrar+Internal.h"
#import "UATagGroupsRegistrar+Internal.h"
#import "UAExtendableChannelRegistration.h"
#import "UAAttributeRegistrar+Internal.h"
#import "UAPushableComponent.h"

extern NSString *const UAChannelTagsSettingsKey;
extern NSString *const UAChannelCreationOnForeground;

@interface UAChannel () <UAChannelRegistrarDelegate, UATagGroupsRegistrarDelegate, UAExtendableChannelRegistration, UAPushableComponent, UAAttributeRegistrarDelegate>

/**
 * Allows disabling channel registration before a channel is created.  Channel registration will resume
 * when this flag is set to `YES`.
 *
 * Set this to `NO` to disable channel registration. Defaults to `YES`.
 */
@property (nonatomic, assign, getter=isChannelCreationEnabled) BOOL channelCreationEnabled;

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                       localeManager:(UALocaleManager *)localeManager;

+ (instancetype)channelWithDataStore:(UAPreferenceDataStore *)dataStore
                              config:(UARuntimeConfig *)config
                  notificationCenter:(NSNotificationCenter *)notificationCenter
                    channelRegistrar:(UAChannelRegistrar *)channelRegistrar
                  tagGroupsRegistrar:(UATagGroupsRegistrar *)tagGroupsRegistrar
                  attributeRegistrar:(UAAttributeRegistrar *)attributeRegistrar
                       localeManager:(UALocaleManager *)localeManager
                                date:(UADate *)date
                         taskManager:(UATaskManager *)taskManager;

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

/**
 * Removes the existing channel and causes the registrar to create a new channel on next registration.
 */
- (void)reset;

@end


