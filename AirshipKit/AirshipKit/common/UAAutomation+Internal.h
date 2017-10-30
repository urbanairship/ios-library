/* Copyright 2017 Urban Airship and Contributors */


#import "UAAutomation.h"
#import "UAAnalytics+Internal.h"
#import <UIKit/UIKit.h>
#import "UAAutomationEngine+Internal.h"
@class UAAutomationStore;

/*
 * SDK-private extensions to UAAutomation
 */
@interface UAAutomation() <UAAutomationEngineDelegate>

///---------------------------------------------------------------------------------------
/// @name Automation Internal Properties
///---------------------------------------------------------------------------------------

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAPreferenceDataStore *preferenceDataStore;

/**
 * The preference data store.
 */
@property (nonatomic, strong) UAAutomationEngine *automationEngine;

///---------------------------------------------------------------------------------------
/// @name Automation Internal Methods
///---------------------------------------------------------------------------------------

/**
 * Automation constructor.
 */
+ (instancetype)automationWithConfig:(UAConfig *)config;

@end
