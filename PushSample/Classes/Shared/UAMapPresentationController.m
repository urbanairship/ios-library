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
#import "UAMapPresentationController.h"
#import "UAGlobal.h"
#import "UALocationDemoAnnotation.h"
#import "UALocationService.h"

@implementation UAMapPresentationController
@synthesize locationService = locationService_;
@synthesize locations = locations_;
@synthesize mapView = mapView_;
@synthesize annotations = annotations_;
@synthesize rightButton = rightButton_;

- (void) dealloc {
    RELEASE_SAFELY(locationService_);
    RELEASE_SAFELY(locations_);
    RELEASE_SAFELY(annotations_);
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!locations_) {
        self.locations = [NSMutableArray array];
    }
    NSLog(@"LOCATIONS ARRAY %@", locations_);
    self.annotations = [NSMutableArray array];
    [self convertLocationsToAnnotations];
    self.navigationItem.rightBarButtonItem = rightButton_;
}

- (void)moveSpanToCoordinate:(CLLocationCoordinate2D)location {
    MKCoordinateSpan span = MKCoordinateSpanMake(0.05, 0.05);
    MKCoordinateRegion region = MKCoordinateRegionMake(location, span);
    [mapView_ setRegion:region animated:YES];
}

- (void)viewDidUnload
{
    self.mapView = nil;
    self.rightButton = nil;
    [super viewDidUnload];
}

- (void)viewWillDisappear:(BOOL)animated {
    mapView_.delegate = nil; // delegate is set in xib
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)convertLocationsToAnnotations {
    for (CLLocation* location in locations_) {
        UALocationDemoAnnotation *annotation = [UALocationDemoAnnotation locationAnnotationFromLocation:location];
        [annotations_ addObject:annotation];
    }
    NSLog(@"ANNOTATIONS %@", annotations_);
}

- (void)annotateMap {
    NSLog(@"annotateMap");
    [mapView_ addAnnotations:annotations_];
    rightButton_.title = @"-Pin";
}

- (IBAction)rightBarButtonPressed:(id)sender {
    NSLog(@"Right bar button pressed");
    // The Map                   
    if ([[mapView_ annotations] count] > 1) {
        NSLog(@"Removing annotations");
        [mapView_ removeAnnotations:annotations_];
        rightButton_.title = @"+Pin";
    }
    else {
        NSLog(@"Adding annotations");
        [self annotateMap];
    }
}


#pragma mark -
#pragma mark MKMapViewDelegate 

- (void)mapView:(MKMapView *)mapView didChangeUserTrackingMode:(MKUserTrackingMode)mode animated:(BOOL)animated {
    NSLog(@"didChangeUserTrackingMode");
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id < MKAnnotation >)annotation {
    // Return nil for the MKUserLocation object
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        NSLog(@"Returning nil for MKUserLocation Lat:%f Long:%f", annotation.coordinate.latitude, annotation.coordinate.longitude);
        return nil;
    }
    NSLog(@"Creating view for annotation %@", annotation);
    
    if (!annotation) {
        NSLog(@"ANNOTATION IS NIL!!!!");
    }
    MKPinAnnotationView *pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
    pinView.pinColor = MKPinAnnotationColorPurple;
    pinView.animatesDrop = YES;
    return [pinView autorelease];
}




@end
