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

@implementation UAMapPresentationController
@synthesize locations = locations_;
@synthesize mapView = mapView_;
@synthesize annotations = annotations_;
@synthesize annotationViews = annotationViews_;
@synthesize rightButton = rightButton_;

- (void) dealloc {
    RELEASE_SAFELY(locations_);
    RELEASE_SAFELY(annotations_);
    RELEASE_SAFELY(annotationViews_);
    RELEASE_SAFELY(rightButton_);
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!locations_) {
        self.locations = [NSMutableArray array];
    }
    NSLog(@"LOCATIONS ARRAY %@", locations_);
    CLLocationCoordinate2D pdx = CLLocationCoordinate2DMake(45.525, -122.682);
    MKCoordinateSpan span = MKCoordinateSpanMake(0.05, 0.05);
    MKCoordinateRegion region = MKCoordinateRegionMake(pdx, span);
    [mapView_ setRegion:region animated:YES];
    self.annotations = [NSMutableArray array];
    self.annotationViews = [NSMutableArray array];
    [self convertLocationsToAnnotationsAndAnnotationViews];
}

- (void)viewDidUnload
{
    RELEASE_SAFELY(mapView_);
    RELEASE_SAFELY(rightButton_);
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)convertLocationsToAnnotationsAndAnnotationViews {
    int count = 1;
    for (CLLocation* location in locations_) {
        UALocationDemoAnnotation *annotation = [UALocationDemoAnnotation locationAnnotationFromLocation:location];
        [annotations_ addObject:annotation];
        MKPinAnnotationView *pinView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:[NSString stringWithFormat:@"%d", count]];
        pinView.pinColor = MKPinAnnotationColorPurple;
        pinView.animatesDrop = YES;
        [annotationViews_ addObject:pinView];
        [pinView release];
        count++;
    }
    NSLog(@"ANNOTATIONS %@", annotations_);
    NSLog(@"ANNOTATION_VIEWS %@", annotationViews_);
}

- (void)annotateMap {
    [mapView_ addAnnotations:annotations_];
    rightButton_.title = @"-Pin";
}

- (IBAction)rightBarButtonPressed:(id)sender {
    NSLog(@"Right bar button pressed");
    // The Map                   
    if ([[mapView_ annotations] count] > 1) {
        [mapView_ removeAnnotations:annotations_];
        rightButton_.title = @"+Pin";
    }
    else {
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
    if ([annotation isKindOfClass:[MKUserLocation class]] ) {
        return nil;
    }
    NSUInteger index = [annotations_ indexOfObject:annotation];
    MKAnnotationView *view = [annotationViews_ objectAtIndex:index];
    return view;
}




@end
