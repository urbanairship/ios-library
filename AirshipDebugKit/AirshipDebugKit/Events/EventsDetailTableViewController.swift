/* Copyright 2019 Urban Airship and Contributors */

import UIKit
import AirshipKit
import MapKit

class EventsDetailTableViewController: UITableViewController {
    @IBOutlet private weak var typeLabel: UILabel!
    @IBOutlet private weak var timeLabel: UILabel!
    @IBOutlet private weak var dataLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    var event: Event? {
        didSet {
            refresh()
        }
    }

    func refresh() {
        if let event = event {
            if let typeLabel = typeLabel {
                typeLabel.text = event.eventType
            }

            if let timeLabel = timeLabel {
                timeLabel.text = event.time.toPrettyDateString()
            }

            if let dataLabel = dataLabel {
                dataLabel.text = event.data
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return event?.eventID
        }

        return nil
    }
}

