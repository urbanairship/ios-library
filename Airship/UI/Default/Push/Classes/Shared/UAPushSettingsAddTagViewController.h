//
//  UAPushSettingsAddTagViewController.h
//  PushSampleLib
//
//  Created by Jeff Towle on 2/1/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol UAPushSettingsAddTagDelegate

- (void)addTag:(NSString *)tag;
- (void)cancelAddTag;

@end


@interface UAPushSettingsAddTagViewController : UIViewController {
    
    id<UAPushSettingsAddTagDelegate> tagDelegate;
    
    UIBarButtonItem *cancelButton;
    UIBarButtonItem *saveButton;
    
    IBOutlet UITableView *tableView;
    IBOutlet UITableViewCell *tagCell;
    IBOutlet UITableViewCell *textCell;
    IBOutlet UILabel *textLabel;
    IBOutlet UITextField *tagField;
    NSString *text;
}

@property (nonatomic, assign) id<UAPushSettingsAddTagDelegate> tagDelegate;
@property (nonatomic, retain) UITableView *tableView;
@property (nonatomic, retain) UITableViewCell *tagCell;
@property (nonatomic, retain) UITableViewCell *textCell;
@property (nonatomic, retain) UILabel *textLabel;
@property (nonatomic, retain) UITextField *tagField;

@end
