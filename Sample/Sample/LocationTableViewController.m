/*
 Copyright 2009-2015 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC ``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// Import the Urban Airship umbrella header, using either
// the framework or the header search paths
#if __has_include("AirshipKit/AirshipKit.h")
#import <AirshipKit/AirshipKit.h>
#else
#import "AirshipLib.h"
#endif

#import "LocationTableViewController.h"

@interface LocationTableViewController ()

@end

@implementation LocationTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.activityIndicator.hidden = YES;

    UALocationService *locationService = [UAirship shared].locationService;
    [locationService setSingleLocationDesiredAccuracy:kCLLocationAccuracyHundredMeters];
    [locationService setTimeoutForSingleLocationService:10.0];
    locationService.delegate = self;

    self.tableView.scrollEnabled = false;

    UIBarButtonItem *refreshCoordinates = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                        target:self
                                                                                        action:@selector(refreshCoordinates)];

    self.navigationItem.rightBarButtonItem = refreshCoordinates;

    [self refreshCoordinates];
}

- (void)refreshCoordinates {
    if (![self checkForLocationAuthorization]) {
        return;
    }
    UALocationService *locationService = [UAirship shared].locationService;
    [locationService reportCurrentLocation];
    self.activityIndicator.hidden = NO;
    [self.activityIndicator startAnimating];
}

- (BOOL)checkForLocationAuthorization {
    BOOL locationServiceEnabled = [UALocationService locationServicesEnabled];
    BOOL locationServiceAuthorized = [UALocationService locationServiceAuthorized];
    BOOL airshipAllowedToUseLocation = [UALocationService airshipLocationServiceEnabled];

    if (!(locationServiceEnabled && locationServiceAuthorized && airshipAllowedToUseLocation)) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Location Error"
                                                                                 message:@"The location service is either, not authorized, enabled, or Urban Airship does not have permission to use it."
                                                                          preferredStyle:UIAlertControllerStyleAlert];

        [alertController addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                                            style:UIAlertActionStyleCancel
                                                          handler:nil]];

        [self presentViewController:alertController animated:YES completion:nil];
        return NO;
    }
    return YES;
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark UALocationServiceDelegate

- (void)locationService:(UALocationService *)service didFailWithError:(NSError *)error {
    UALOG(@"LOCATION_ERROR, %@", error.description);
}

- (void)locationService:(UALocationService *)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    UALOG(@"LOCATION_AUTHORIZATION_STATUS %u", status);
}

- (void)locationService:(UALocationService *)service didUpdateLocations:(NSArray *)locations {
    [self.activityIndicator stopAnimating];
    self.activityIndicator.hidden = YES;

    CLLocation *newLocation = [locations lastObject];

    UALOG(@"LOCATION_UPDATE LAT:%f LONG:%f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);

    self.latitudeCell.detailTextLabel.text = [[NSString alloc] initWithFormat:@"%f", newLocation.coordinate.latitude];
    self.longitudeCell.detailTextLabel.text = [[NSString alloc] initWithFormat:@"%f", newLocation.coordinate.longitude];
}

@end
