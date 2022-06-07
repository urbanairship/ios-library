/* Copyright Airship and Contributors */

#import "UALocation.h"
#import "UALocationCoreImport.h"

@class UAPreferenceDataStore;
@class UAPrivacyManager;
@class UASystemVersion;
@protocol UAChannelProtocol;
@protocol UAAnalyticsProtocol;
@class UAAnalytics;
@class UAPermissionsManager;


/*
 * SDK-private extensions to UALocation
 */
@interface UALocation() <CLLocationManagerDelegate>

NS_ASSUME_NONNULL_BEGIN

///---------------------------------------------------------------------------------------
/// @name Location Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The location manager.
 */
@property (nonatomic, strong) CLLocationManager *locationManager;

/**
 * The data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;

/**
 * Flag indicating if location updates have been started or not.
 */
@property (nonatomic, assign, getter=isLocationUpdatesStarted) BOOL locationUpdatesStarted;

/**
 * Location factory method.
 * @param dataStore The data store.
 * @param channel The airship channel.
 * @param privacyManager The privacy manager.
 * @param permissionsManager The permissions manager.
 * @return A location instance.
 */
+ (instancetype)locationWithDataStore:(UAPreferenceDataStore *)dataStore
                              channel:(id<UAChannelProtocol>)channel
                       privacyManager:(UAPrivacyManager *)privacyManager
                   permissionsManager:(UAPermissionsManager *)permissionsManager;


NS_ASSUME_NONNULL_END

@end
