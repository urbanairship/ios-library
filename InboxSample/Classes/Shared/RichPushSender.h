//
//  RichPushSender.h
//  InboxSampleLib
//
//  Created by Marc Sciglimpaglia on 3/8/11.
//  Copyright 2011 Urban Airship. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface RichPushSender : NSObject <UIActionSheetDelegate> {
	
	NSArray *buttonTitles;
	NSMutableDictionary *messages;

}

@property(nonatomic, retain) NSArray *buttonTitles;
@property(nonatomic, retain) NSDictionary *messages;

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)index;

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)index;

@end
