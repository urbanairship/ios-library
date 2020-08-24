/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPersistentQueue+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UARuntimeConfig+Internal.h"
#import "UAPreferenceDataStore.h"
#import "UAAttributeAPIClient+Internal.h"


NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for registrar callbacks.
 */
@protocol UAAttributeRegistrarDelegate <NSObject>
@required

/**
 * Called when mutations have been succesfully uploaded.
 *
 * @param mutations The mutations.
 * @param identifier The identifier associated with the mutations.
 */
- (void)uploadedAttributeMutations:(UAAttributePendingMutations *)mutations
                        identifier:(NSString *)identifier;

@end

/**
 The registrar responsible for routing requests to the attributes APIs.
 */
@interface UAAttributeRegistrar : NSObject

///---------------------------------------------------------------------------------------
/// @name Attribute Registrar Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Factory method to create the channel attribute registrar.
 * @param config The Airship config.
 * @return A new attribute registrar instance.
*/
+ (instancetype)channelRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dateStore;

/**
 * Factory method to create the named user attribute registrar.
 * @param config The Airship config.
 * @return A new attribute registrar instance.
 */
+ (instancetype)namedUserRegistrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dateStore;

/**
 * Factory method to create an attribute registrar for testing.
 * @param APIClient The attributes API client.
 * @param persistentQueue The queue.
 * @param application The application.
 * @return A new attributes registrar instance.
 */
+ (instancetype)registrarWithAPIClient:(UAAttributeAPIClient *)APIClient
                       persistentQueue:(UAPersistentQueue *)persistentQueue
                           application:(UIApplication *)application;

/**
 Method to save pending mutations for asynchronous upload.
 @param mutations The channel attribute mutations to save.
*/
- (void)savePendingMutations:(UAAttributePendingMutations *)mutations;

/**
 * Clears pending mutations.
 */
- (void)clearPendingMutations;

/**
 * Sets the currently associated identifier.
 *
 * @param identifier The identifier.
 * @param clearPendingOnChange Whether pending mutations should be cleared if the identifier has changed.
 */
- (void)setIdentifier:(NSString *)identifier clearPendingOnChange:(BOOL)clearPendingOnChange;

/**
 * Update attributes
 */
- (void)updateAttributes;

/**
 * The current identifier associated with this registrar.
 */
@property (nonatomic, readonly) NSString *identifier;

/**
 * Whether the registrar is enabled. Defaults to `YES`.
 */
@property (nonatomic, assign) BOOL enabled;

/**
 * Pending mutations.
 */
@property (nonatomic, readonly) UAAttributePendingMutations *pendingMutations;

/**
 * The delegate to receive registrar callbacks.
 */
@property (nonatomic, weak) id<UAAttributeRegistrarDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
