/* Copyright Airship and Contributors */

import UIKit

extension UIImage {

    func loadImage(url: URL, attempts: Int) -> UIImage? {
        // Perform attempts, and retry on any failure
        for _ in 0..<attempts {
            if let data = try? Data(contentsOf: url) {
                if let image = UIImage(data: data) {
                    return image
                }
                return nil
            }
        }
        return nil
    }
    
}

class AlertButton: UIButton {
    var actions: Any?
}

@objc(UAPreferenceCenterAlertCell)
open class PreferenceCenterAlertCell: UITableViewCell {
    
    @IBOutlet weak var alertIconIndicator: UIActivityIndicatorView!
    @IBOutlet weak var alertTitle: UILabel!
    @IBOutlet weak var alertDescription: UILabel!
    @IBOutlet weak var alertIcon: UIImageView!
    @IBOutlet weak var alertButton: AlertButton!
    
}
