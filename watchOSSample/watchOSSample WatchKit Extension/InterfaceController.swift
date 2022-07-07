/* Copyright Airship and Contributors */

import WatchKit
import Foundation
import AirshipCore

class InterfaceController: WKInterfaceController {

    @IBOutlet weak var table: WKInterfaceTable!
    
    override func awake(withContext context: Any?) {
        // Configure the table object and get the row controllers.
        table.setRowTypes(["enable_push", "channel_id"])
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        let row = table.rowController(at: 1) as! LabelRowController
        row.itemLabel2.setText(Airship.channel.identifier)
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

}
