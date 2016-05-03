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
import AirshipKit

class TagsTableViewController: UITableViewController {


    let addTagsSegue:String = "addTagsSegue"

    override func viewDidLoad() {
        super.viewDidLoad()

        let addButton:UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: #selector(TagsTableViewController.addTag))
        navigationItem.rightBarButtonItem = addButton
    }

    override func viewDidAppear(animated: Bool) {
        tableView.reloadData()
    }

    func addTag () {
        performSegueWithIdentifier(addTagsSegue, sender: self)
    }

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UAirship.push().tags.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCellWithIdentifier("tagCell", forIndexPath: indexPath)

        if cell.isEqual(nil) {
            cell = UITableViewCell.init(style: UITableViewCellStyle.Default, reuseIdentifier:"tagCell")
        }
        cell.textLabel!.text = UAirship.push().tags[indexPath.row]

        return cell
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete &&
            tableView.cellForRowAtIndexPath(indexPath)?.textLabel?.text?.isEmpty == false) {

            UAirship.push().removeTag((tableView.cellForRowAtIndexPath(indexPath)?.textLabel?.text)!)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)

            UAirship.push().updateRegistration()
        }
    }
}
