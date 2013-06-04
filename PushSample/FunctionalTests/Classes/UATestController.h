//
//  UATestController.h
//  PushSampleLib
//
//  Created by Jeff Towle on 6/1/13.
//
//

#import "KIFTestController.h"

#import "UAPush.h"

@interface UATestController : KIFTestController

@property (nonatomic, retain) NSObject<UAPushNotificationDelegate> *pushDelegate;

@end
