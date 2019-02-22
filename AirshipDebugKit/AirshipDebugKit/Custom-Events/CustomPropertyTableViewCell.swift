/* Copyright Urban Airship and Contributors */

import UIKit

class CustomPropertyTableViewCell: UITableViewCell {

    @IBOutlet var propertyTypeLabel: UILabel!
    @IBOutlet var propertyLabel: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
