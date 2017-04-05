/* Copyright 2017 Urban Airship and Contributors */

@import UIKit;

@interface HomeViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *channelIDButton;
@property (weak, nonatomic) IBOutlet UIButton *enablePushButton;


- (IBAction)buttonTapped:(id)sender;

@end

