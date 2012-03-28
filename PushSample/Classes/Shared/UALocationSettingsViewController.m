/*
 Copyright 2009-2011 Urban Airship Inc. All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
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

#import "UALocationSettingsViewController.h"
#import "UAMapPresentationController.h"
#import "UAGlobal.h"
#import "UALocationCommonValues.h"
#import "UAMapPresentationController.h"

@interface UALocationSettingsViewController ()

@end

@implementation UALocationSettingsViewController

@synthesize locationService = locationService_;
@synthesize locationDisplay = locationDisplay_;
@synthesize reportedLocations = reportedLocations_;
@synthesize latitudes = latitudes_;
@synthesize longitudes = longitudes_;
@synthesize locationTableView = locationTableView_;

- (void)dealloc {
    RELEASE_SAFELY(locationService_);
    RELEASE_SAFELY(locationDisplay_);
    RELEASE_SAFELY(reportedLocations_);
    RELEASE_SAFELY(latitudes_);
    RELEASE_SAFELY(longitudes_);
    [super dealloc];
}

- (void)viewDidUnload
{
    [self turnOffLocationDisplay];
    RELEASE_SAFELY(locationTableView_);
    RELEASE_SAFELY(locationDisplay_);
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewDidLoad
{
    NSLog(@"viewDidLoad");
    [super viewDidLoad];
    self.reportedLocations = [NSMutableSet setWithCapacity:10];
    self.latitudes = [NSMutableArray arrayWithCapacity:10];
    self.longitudes = [NSMutableArray arrayWithCapacity:10];
    self.locationDisplay = [NSMutableArray arrayWithCapacity:3];
    [self setupLocationDisplay];
    [locationTableView_ setScrollEnabled:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.locationService = [[[UALocationService alloc] initWithPurpose:@"Location Demo"] autorelease];
    locationService_.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    locationService_.delegate = nil;
    RELEASE_SAFELY(locationService_);
    [super viewWillDisappear:animated];
}


#pragma mark -
#pragma mark Rotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

#pragma mark -
#pragma mark GUI operations

- (void)turnOffLocationDisplay {
    [locationDisplay_ removeObjectsInRange:NSMakeRange(1, ([locationDisplay_ count] -1))];
    NSUInteger rows = [locationTableView_ numberOfRowsInSection:0];
    NSMutableArray *arrayOfDeletes = [NSMutableArray arrayWithCapacity:3];
    for (NSUInteger i=1; i < rows; i++) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:i inSection:0];
        [arrayOfDeletes addObject:path];
    }
    [locationTableView_ deleteRowsAtIndexPaths:arrayOfDeletes withRowAnimation:UITableViewRowAnimationFade];
}

- (void)setupLocationDisplay {
    if (locationDisplay_) {
        [locationDisplay_ removeAllObjects];
    }
    [locationDisplay_ addObject:@"Location"];
}

#pragma mark -
#pragma mark LocationSettings methods

- (void)addLocationToData:(CLLocation*)location {
    [reportedLocations_ addObject:location];
    NSNumber *latitude = [NSNumber numberWithDouble:location.coordinate.latitude];
    NSNumber *longitude = [NSNumber numberWithDouble:location.coordinate.longitude];
    [latitudes_ addObject:latitude];
    [longitudes_ addObject:longitude];
    if ([locationDisplay_ count] < 3) {
        [locationDisplay_ addObject:@"Lat:"];
        [locationDisplay_ addObject:@"Long:"];
        NSIndexPath *latPath = [NSIndexPath indexPathForRow:1 inSection:0];
        NSIndexPath *longPath = [NSIndexPath indexPathForRow:2 inSection:0];
        NSArray *indexPaths = [NSArray arrayWithObjects:latPath,longPath, nil];
        [locationTableView_ insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark -
#pragma mark IBAction Button Methods

- (IBAction)getLocationPressed:(id)sender {
    NSLog(@"Get Location pressed");
    [self checkAndAlertForLocationAuthorization];
    [locationService_ reportCurrentLocation];
}

- (void)checkAndAlertForLocationAuthorization {
    // Check the system level permissions (global location settings)
    BOOL locationServiceEnabled = [UALocationService locationServicesEnabled];
    // Check the system level per app location settings
    BOOL locationServiceAuthorized = [UALocationService locationServiceAuthorized];
    // Check if Urban Airship is allowed to use location
    BOOL airshipAllowedToUseLocation = [UALocationService airshipLocationServiceEnabled];
    if (!(locationServiceEnabled && locationServiceAuthorized && airshipAllowedToUseLocation)) {
        UIAlertView *alertView = [[[UIAlertView alloc] initWithTitle:@"Location Error" 
                                                            message:@"The location service is either, not authorized, enabled, or Urban Airship does not have permissinon to use it" 
                                                           delegate:nil 
                                                  cancelButtonTitle:@"Dismiss" 
                                                  otherButtonTitles:nil] autorelease];
        [alertView show];
    }
}

- (IBAction)mapLocationPressed:(id)sender{
    UAMapPresentationController *mapController = [[UAMapPresentationController alloc] initWithNibName:@"UAMapPresentationViewController" 
                                                                                               bundle:[NSBundle mainBundle]];
    mapController.locations = [NSMutableArray arrayWithArray:[reportedLocations_ allObjects]];
    [mapController autorelease];
    [self.navigationController pushViewController:mapController animated:YES];
}

#pragma mark -
#pragma mark UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (0 == [indexPath indexAtPosition:1]) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"location"] autorelease];
        cell.textLabel.text = [locationDisplay_ objectAtIndex:0];
        cell.textLabel.textAlignment = UITextAlignmentCenter;
    }
    if(1 == [indexPath indexAtPosition:1]) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"latitude"] autorelease];
        cell.textLabel.text = [locationDisplay_ objectAtIndex:[indexPath indexAtPosition:1]];
        cell.detailTextLabel.text = [[latitudes_ lastObject] stringValue];
    }
    if (2 == [indexPath indexAtPosition:1]) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"longitude"] autorelease];
        cell.textLabel.text = [locationDisplay_ objectAtIndex:[indexPath indexAtPosition:1]];
        cell.detailTextLabel.text = [[longitudes_ lastObject] stringValue];
    }
    return cell ;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [locationDisplay_ count];
}

#pragma mark -
#pragma mark UALocationServiceDelegate

- (void)locationService:(UALocationService*)service didFailWithError:(NSError*)error {
    NSLog(@"LOCATION_ERROR, %@", error.description);
}
- (void)locationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"LOCATION_AUTHORIZATION_STATUS %u", status);
}
- (void)locationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation {
    NSLog(@"LOCATION_UPDATE LAT:%f LONG:%f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
    [self addLocationToData:newLocation];
}


@end
