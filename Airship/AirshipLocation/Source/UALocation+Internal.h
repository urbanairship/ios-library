/* Copyright Airship and Contributors */

#import "UALocation.h"


#if __has_include(<AirshipCore/AirshipCore.h>)
#import <AirshipCore/AirshipCore.h>
#else
#import "UAAnalytics.h"
#import "UASystemVersion.h"
#import "UAExtendableChannelRegistration.h"
#import "UAExtendableAnalyticsHeaders.h"
#import "UAAppStateTracker.h"
#import "UALocationEvent.h"
#import "UAChannel.h"
#endif

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
 * The system version.
 */
@property (nonatomic, strong) UASystemVersion *systemVersion;

/**
 * Flag indicating if location updates have been started or not.
 */
@property (nonatomic, assign, getter=isLocationUpdatesStarted) BOOL locationUpdatesStarted;

/**
 * Location factory method.
 * @param dataStore The data store.
 * @param channel The airship channel.
 * @param analytics The analytics instance.
 * @return A location instance.
 */
+ (instancetype)locationWithDataStore:(UAPreferenceDataStore *)dataStore
                              channel:(UAChannel<UAExtendableChannelRegistration> *)channel
                            analytics:(UAAnalytics<UAExtendableAnalyticsHeaders> *)analytics;

NS_ASSUME_NONNULL_END

@end
