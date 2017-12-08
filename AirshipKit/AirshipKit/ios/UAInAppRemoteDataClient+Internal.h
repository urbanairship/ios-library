/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

@class UAInAppMessageManager;
@class UARemoteDataManager;
@class UAPreferenceDataStore;

/**
 * Client class to connect the Remote Data and the In App Messaging services.
 * This class parses the remote data payloads, and asks the in app scheduler to
 * create, update, or delete In App messages, as appropriate.
 */
@interface UAInAppRemoteDataClient : NSObject

/**
 * Create a remote data client for in-app messaging.
 *
 * @param delegate The delegate to be used to schedule in-app messages.
 * @param remoteDataManager The remote data manager.
 * @param dataStore A UAPreferenceDataStore to store persistent preferences
 */
+ (instancetype)clientWithScheduler:(UAInAppMessageManager *)delegate remoteDataManager:(UARemoteDataManager *)remoteDataManager dataStore:(UAPreferenceDataStore *)dataStore;

@end
