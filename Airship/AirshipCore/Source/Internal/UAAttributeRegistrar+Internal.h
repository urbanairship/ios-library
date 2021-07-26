/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAPersistentQueue+Internal.h"
#import "UAAttributePendingMutations.h"
#import "UARuntimeConfig+Internal.h"

@class UAPreferenceDataStore;
@class UAAttributeAPIClient;
@class UADisposable;

NS_ASSUME_NONNULL_BEGIN


/**
 * Attribute upload results.
 */
typedef NS_ENUM(NSUInteger, UAAttributeUploadResult) {
    /**
     * Attribute either uploaded successfully or failed with an unrecoverable error code.
     */
    UAAttributeUploadResultFinished,

    /**
     * Attribute already up to date..
     */
    UAAttributeUploadResultUpToDate,

    /**
     * Attribute uploads failed and should retry.
     */
    UAAttributeUploadResultFailed,
};

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
- (void)setIdentifier:(nullable NSString *)identifier clearPendingOnChange:(BOOL)clearPendingOnChange;

/**
 * Update attributes
 *
 * @param completionHandler The completion handler.
 * @return UADisposable object
 */
- (UADisposable *)updateAttributesWithCompletionHandler:(void(^)(UAAttributeUploadResult result))completionHandler;

/**
 * The current identifier associated with this registrar.
 */
@property (atomic, readonly, nullable) NSString *identifier;

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
