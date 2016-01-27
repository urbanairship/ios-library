/*
Copyright 2009-2016 Urban Airship Inc. All rights reserved.

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

import UIKit

class LocationTableViewController: UITableViewController, UALocationServiceDelegate {

    @IBOutlet var latitudeCell: UITableViewCell!
    @IBOutlet var longitudeCell: UITableViewCell!

    @IBOutlet var activityIndicator: UIActivityIndicatorView!

    var locationService: UALocationService = UAirship.shared().locationService

    override func viewDidLoad() {
        super.viewDidLoad()

        activityIndicator.hidden = true

        locationService.setSingleLocationDesiredAccuracy(kCLLocationAccuracyHundredMeters)
        locationService.setTimeoutForSingleLocationService(10.0)
        locationService.delegate = self

        tableView.scrollEnabled = false

        let refreshCoordinates: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action:"refreshCoordinates")
        navigationItem.rightBarButtonItem = refreshCoordinates

        self.refreshCoordinates()
    }

    func refreshCoordinates () {
        if (!checkForLocationAuthorization()) {
            return
        }

        locationService.reportCurrentLocation()
        activityIndicator.hidden = false
        activityIndicator.startAnimating()
    }

    func checkForLocationAuthorization () -> Bool {
        let locationServiceEnabled:Bool = UALocationService.locationServicesEnabled()
        let locationServiceAuthorized:Bool = UALocationService.locationServiceAuthorized()
        let airshipAllowedToUseLocation:Bool = UALocationService.airshipLocationServiceEnabled()

        if !(locationServiceEnabled && locationServiceAuthorized && airshipAllowedToUseLocation) {

            let alertController: UIAlertController = UIAlertController(title: "Location Error", message: "The location service is either, not authorized, enabled, or Urban Airship does not have permission to use it.",
                preferredStyle: UIAlertControllerStyle.Alert)

            alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.Cancel, handler: nil))
            self.presentViewController(alertController, animated: true, completion: nil)

            return false
        }

        return true
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }

    // MARK: - UALocationServiceDelegate -

    func locationService(service: UALocationService, didFailWithError error: NSError) {
        print("LOCATION_ERROR, %@", error.description)
    }

    func locationService(service: UALocationService, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
        print("LOCATION_AUTHORIZATION_STATUS %@", status)
    }

    func locationService(service: UALocationService, didUpdateLocations locations: [AnyObject]) {
        activityIndicator.stopAnimating()
        activityIndicator.hidden = true

        let newLocation: CLLocation = locations.last as! CLLocation

        latitudeCell.detailTextLabel!.text = String(newLocation.coordinate.latitude)
        longitudeCell.detailTextLabel!.text = String(newLocation.coordinate.longitude)
    }
}
