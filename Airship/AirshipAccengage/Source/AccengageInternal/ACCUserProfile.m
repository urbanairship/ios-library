/* Copyright Airship and Contributors */

#import "ACCUserProfile.h"

#if UA_USE_MODULE_AIRSHIP_IMPORTS
@import AirshipCore;
#else
#import "UAAccengageModuleLoaderFactory.h"
#import "ACCDeviceInformationSet+Internal.h"
#endif

@implementation ACCUserProfile

#pragma mark - Update device information
///--------------------------------------

- (void)updateDeviceInformation:(ACCDeviceInformationSet *)deviceInformation withCompletionHandler:(nullable void(^)(NSError *__nullable error))completionHandler {
    
    UAAttributeMutations *mutations = deviceInformation.attributeMutations;
    
    // Apply the attribute changes to the channel
    [UAirship.channel applyAttributeMutations:mutations];
    
    if (completionHandler) {
        completionHandler(nil);
    }
}

@end
