/* Copyright Urban Airship and Contributors */

#import "MessageCenterViewController.h"

@implementation MessageCenterViewController

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.style = [UAirship messageCenter].style;

    // Match style of iOS Mail app
    self.style.cellTitleHighlightedColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
}

- (void)displayMessageForID:(NSString *)messageID {
    [self.listViewController displayMessageForID:messageID];
}

@end
