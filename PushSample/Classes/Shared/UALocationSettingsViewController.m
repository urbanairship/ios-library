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

@interface UALocationSettingsViewController ()

@end

@implementation UALocationSettingsViewController

@synthesize locationService = locationService_;
@synthesize locationDisplay = locationDisplay_;
@synthesize reportedLocations = reportedLocations_;
@synthesize latitudes = latitudes_;
@synthesize longitudes = longitudes_;
@synthesize locationsToPlot = locationsToPlot_;
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
    RELEASE_SAFELY(locationTableView_);
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.locationService = [[[UALocationService alloc] initWithPurpose:@"Location Demo"] autorelease];
    self.locationDisplay = [NSMutableArray arrayWithCapacity:3];
    self.reportedLocations = [NSMutableSet setWithCapacity:10];
    self.latitudes = [NSMutableArray arrayWithCapacity:10];
    self.longitudes = [NSMutableArray arrayWithCapacity:10];
    self.locationsToPlot = [NSMutableArray array];
    locationService_.delegate = self;
    [UALocationService setAirshipLocationServiceEnabled:YES];
    locationService_.promptUserForLocationServices = YES;
    locationService_.backgroundLocationServiceEnabled = YES;
    //locationService_.standardLocationDistanceFilter = 50.0;
    [self setupLocationDisplay];
    [locationTableView_ setScrollEnabled:NO];
	// Do any additional setup after loading the view, typically from a nib.
}


#pragma mark -
#pragma mark Rotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

- (void)setupLocationDisplay {
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

- (NSMutableArray*)readLocationsFromDisk {
    NSString *docsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *storagePath = [docsDir stringByAppendingPathComponent:@"LocationTest.plist"];
    return [NSKeyedUnarchiver unarchiveObjectWithFile:storagePath];   
}

- (BOOL)writeLocationsToDisk:(NSSet *)locations {
    NSString *docsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *storagePath = [docsDir stringByAppendingPathComponent:@"LocationTest.plist"];
    NSMutableArray *diskLocations = [self readLocationsFromDisk];
    if (!diskLocations) {
        diskLocations = [NSMutableArray array];
    }
    [diskLocations addObjectsFromArray:[locations allObjects]];
    BOOL success = [NSKeyedArchiver archiveRootObject:diskLocations toFile:storagePath];
    if (success) {
        NSLog(@"Wrote values to disk %@", locations);
    }
    else {
        NSLog(@"Failed to write values to disk %@", locations);
    }
    return success;
}

- (BOOL)writeLocationToDisk:(CLLocation *)location {
  return [self writeLocationsToDisk:[NSSet setWithObject:location]];
}

#pragma mark -
#pragma mark IBAction Button Methods

- (IBAction)getLocationPressed:(id)sender {
    NSLog(@"Get Location pressed");
    [locationService_ reportCurrentLocation];
}

- (IBAction)saveLocationPressed:(id)sender {
    NSLog(@"Stop Location pressed");
    [self turnOffLocationDisplay];
    [self writeLocationsToDisk:reportedLocations_];
}

- (IBAction)loadLocationPressed:(id)sender {
    NSMutableArray *locations = [self readLocationsFromDisk];
    if(!locations)return;
    [reportedLocations_ addObjectsFromArray:locations];
}

- (IBAction)clearLocationPressed:(id)sender {
    [reportedLocations_ removeAllObjects];
}

- (IBAction)clearSavedDataPressed:(id)sender{
    NSString *docsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *storagePath = [docsDir stringByAppendingPathComponent:@"LocationTest.plist"];
    NSError *eraseError = nil;
    [[NSFileManager defaultManager] removeItemAtPath:storagePath error:&eraseError];
    if(eraseError) {
        NSLog(@"ERROR erasing %@ %@", storagePath, eraseError);
    }
    else {
        NSLog(@"ERASED file at path %@", storagePath);
    }
}

- (IBAction)toggleBackgroundLocation:(id)sender {
    if (locationService_.standardLocationServiceStatus == UALocationProviderUpdating) {
        [locationService_ stopReportingStandardLocation];
        [(UIButton*)sender setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        NSLog(@"LOCATION STOPPED");
    }
    else {
        [locationService_ startReportingStandardLocation];
        [(UIButton*)sender setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        NSLog(@"LOCATION STARTED");
    }
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

- (void)UALocationService:(UALocationService*)service didFailWithError:(NSError*)error {
    NSLog(@"LOCATION_ERROR, %@", error.description);
}
- (void)UALocationService:(UALocationService*)service didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSLog(@"LOCATION_AUTHORIZATION_STATUS %u", status);
}
- (void)UALocationService:(UALocationService*)service didUpdateToLocation:(CLLocation*)newLocation fromLocation:(CLLocation*)oldLocation {
    NSLog(@"LOCATION_UPDATE LAT:%f LONG:%f", newLocation.coordinate.latitude, newLocation.coordinate.longitude);
    [self addLocationToData:newLocation];
    if([UIApplication sharedApplication].applicationState != UIApplicationStateActive){
        [self writeLocationToDisk:newLocation];
    }
}


@end
