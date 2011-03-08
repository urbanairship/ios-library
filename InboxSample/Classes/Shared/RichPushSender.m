//
//  RichPushSender.m
//  InboxSampleLib
//
//  Created by Marc Sciglimpaglia on 3/8/11.
//  Copyright 2011 Urban Airship. All rights reserved.
//

#import "RichPushSender.h"


@implementation RichPushSender

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)index {
	NSLog(@"ZOMG, you dismissed at %d", index);
	
	//send a rich push here
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)index {
}
	
@end
