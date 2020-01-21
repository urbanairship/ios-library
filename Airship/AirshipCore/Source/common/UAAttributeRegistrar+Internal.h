/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>
#import "UAComponent+Internal.h"

@class UAAttributePendingMutations;
@class UAAttributeAPIClient;
@class UADate;

NS_ASSUME_NONNULL_BEGIN

/**
 The registrar responsible for routing requests to the channel attributes API.
 */
@interface UAAttributeRegistrar : UAComponent

///---------------------------------------------------------------------------------------
/// @name Attribute Registrar Internal Methods
///---------------------------------------------------------------------------------------

/**
 Factory method to create an attribute registrar.
 @param config The Airship config.
 @param dataStore The shared data store.
 @return A new attribute registrar instance.
*/
+ (instancetype)registrarWithConfig:(UARuntimeConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

/**
 Factory method to create an attribute registrar for testing.
 @param dataStore The shared data store.
 @param apiClient The attributes API client.
 @param operationQueue An NSOperation queue used to synchronize changes to attributes.
 @param application The application.
 @param date The date for setting the timestamp.
 @return A new attributes registrar instance.
 */
+ (instancetype)registrarWithDataStore:(UAPreferenceDataStore *)dataStore
                             apiClient:(UAAttributeAPIClient *)apiClient
                        operationQueue:(NSOperationQueue *)operationQueue
                           application:(UIApplication *)application
                                  date:(UADate *)date;

/**
 Method to save pending mutations for asynchronous upload.
 @param mutations The channel attribute mutations to save.
*/
- (void)savePendingMutations:(UAAttributePendingMutations *)mutations;

/**
 * Method to delete pending mutations.
 */
- (void)deletePendingMutations;

/**
 Method to update remote attributes with new mutations.
 @param identifier The channel identifier.
*/
- (void)updateAttributesForChannel:(NSString *)identifier;

@end

NS_ASSUME_NONNULL_END
