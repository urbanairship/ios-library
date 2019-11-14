/* Copyright Airship and Contributors */

/**
 * NSNotification event when a channel is created. The event
 * will contain the channel ID under `UAChannelCreatedEventChannelKey`
 * and a flag under `UAChannelCreatedEventExistingKey` indicating if the
 * the channel was restored or a new channel was created.
 */
extern NSString *const UAChannelCreatedEvent;

/**
 * NSNotification event when a channel is updated. The event
 * will contain the channel ID under `UAChannelUpdatedEventChannelKey`
 */
extern NSString *const UAChannelUpdatedEvent;

/**
 * NSNotificationCevent when channel registration fails.
 */
extern NSString *const UAChannelRegistrationFailedEvent;

/**
 * Channel ID key for the channel created event.
 */
extern NSString *const UAChannelCreatedEventChannelKey;

/**
 * Channel ID key for the channel updated event.
 */
extern NSString *const UAChannelUpdatedEventChannelKey;

/**
 * Channel existing key for the channel created event.
 */
extern NSString *const UAChannelCreatedEventExistingKey;
