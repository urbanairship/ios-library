/* Copyright Airship and Contributors */

#if UA_USE_AIRSHIP_IMPORT
#import <Airship/Airship.h>
#elif UA_USE_MODULE_IMPORT
#import <AirshipCore/AirshipCore.h>
#else
#import "UALocationModuleLoaderFactory.h"
#import "UAModuleLoader.h"
#import "UALocationProvider.h"
#import "UAEvent.h"
#import "UAAppStateTracker.h"
#import "UAComponent.h"
#import "UAAnalytics.h"
#import "UASystemVersion.h"
#import "UAExtendableChannelRegistration.h"
#import "UAExtendableAnalyticsHeaders.h"
#import "UAAppStateTracker.h"
#import "UAChannel.h"
#endif
