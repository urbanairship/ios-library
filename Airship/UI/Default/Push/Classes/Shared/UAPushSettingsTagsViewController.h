//
//  UAPushSettingsTagsViewController.h
//  PushSampleLib
//
//  Created by Jeff Towle on 1/31/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UAPushSettingsAddTagViewController.h"

@interface UAPushSettingsTagsViewController : UITableViewController<UAPushSettingsAddTagDelegate> {

    UAPushSettingsAddTagViewController *addTagController;
    UIBarButtonItem *addButton;
    
}

- (void)addItem:(id)sender;

@end
