/* Copyright 2018 Urban Airship and Contributors */

import UIKit
import AirshipKit

/**
 * The TextInfoDetailViewController displays the details of an IAA
 * text info block. It is used to display the details of headings,
 * bodies and button labels.
 */
class TextInfoDetailViewController: UAStaticTableViewController {
    public static let segueID = "ShowTextInfoDetail"
    
    /* The UAInAppMessageTextInfo to be displayed. */
    public var textInfo : UAInAppMessageTextInfo?

    @IBOutlet var textCell: UITableViewCell!
    @IBOutlet var textLabel: UILabel!
    @IBOutlet var alignmentCell: UITableViewCell!
    @IBOutlet var alignmentLabel: UILabel!
    @IBOutlet var styleCell: UITableViewCell!
    @IBOutlet var styleLabel: UILabel!
    @IBOutlet var fontFamiliesCell: UITableViewCell!
    @IBOutlet var fontFamiliesLabel: UILabel!
    @IBOutlet var sizeCell: UITableViewCell!
    @IBOutlet var sizeLabel: UILabel!
    @IBOutlet var colorCell: UITableViewCell!
    @IBOutlet var colorLabel: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        refreshView()
    }
    
    @objc func refreshView() {
        guard let textInfo = textInfo else { return }
        
        var fontFamiliesDescription : String?
        var colorDescription : String?

        // text
        updateOrHideCell(textCell, label: textLabel, newText: textInfo.text)

        // alignment
        switch (textInfo.alignment) {
        case .none:
            alignmentLabel.text = "ua_textinfo_alignment_none".localized()
        case .left:
            alignmentLabel.text = "ua_textinfo_alignment_left".localized()
        case .center:
            alignmentLabel.text = "ua_textinfo_alignment_center".localized()
        case .right:
            alignmentLabel.text = "ua_textinfo_alignment_right".localized()
        }
        
        // style
        var styles:[String] = []
        if (textInfo.style.contains(.bold)) {
            styles.append("ua_textinfo_style_bold".localized())
        }
        if (textInfo.style.contains(.italic)) {
            styles.append("ua_textinfo_style_italic".localized())
        }
        if (textInfo.style.contains(.underline)) {
            styles.append("ua_textinfo_style_underline".localized())
        }
        if (styles.count == 0) {
            styles.append("ua_textinfo_style_normal".localized())
        }        
        styleLabel.text = styles.joined(separator: ", ")

        // fontFamilies
        if let fontFamilies = textInfo.fontFamilies {
            if (fontFamilies.count > 0) {
                fontFamiliesDescription = "\(fontFamilies.count)"
            }
        }
        updateOrHideCell(fontFamiliesCell, label: fontFamiliesLabel, newText: fontFamiliesDescription)

        // size
        sizeLabel.text = "\(textInfo.sizePoints)"
        
        // color
        colorDescription = descriptionForColor(textInfo.color)
        updateOrHideCell(colorCell, label: colorLabel, newText: colorDescription)

        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        // let superview override
        let heightFromSuperview = super.tableView(tableView, heightForRowAt: indexPath)
        if heightFromSuperview != UITableView.automaticDimension {
            return heightFromSuperview
        }
        
        // superview didn't override, so let's check our cells
        if cell == textCell {
            return heightForCell(cell, resizingLabel:textLabel)
        } else {
            return UITableView.automaticDimension
        }
    }

    // TODO - implement Font Families View
}
