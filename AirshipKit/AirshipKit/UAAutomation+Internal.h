/* Copyright 2017 Urban Airship and Contributors */


#import "UAAutomation.h"
#import "UAAnalytics+Internal.h"
#import <UIKit/UIKit.h>

@class UAAutomationStore;

@interface UAAutomation () <UAAnalyticsDelegate>

@property (nonatomic, strong) UAAutomationStore *automationStore;
@property (nonatomic, strong) UAPreferenceDataStore *preferenceDataStore;
@property (nonatomic, copy) NSString *currentScreen;
@property (nonatomic, copy) NSString *currentRegion;


@property (nonatomic, assign) BOOL isForegrounded;
@property (nonatomic, strong) NSMutableArray *activeTimers;
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;

+ (instancetype)automationWithConfig:(UAConfig *)config dataStore:(UAPreferenceDataStore *)dataStore;

@end
