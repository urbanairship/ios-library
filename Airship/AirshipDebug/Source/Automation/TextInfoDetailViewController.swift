/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
import AirshipAutomation
#elseif canImport(Airship)
import Airship
#endif

/**
 * The TextInfoDetailViewController displays the details of an IAA
 * text info block. It is used to display the details of headings,
 * bodies and button labels.
 */
class TextInfoDetailViewController: UAStaticTableViewController {
    public static let segueID = "TextInfoSegue"
    
    /* The UAInAppMessageTextInfo to be displayed. */
    public var textInfo : UAInAppMessageTextInfo?

    @IBOutlet private weak var textCell: UITableViewCell!
    @IBOutlet private weak var textTitle: UILabel!
    @IBOutlet private weak var textLabel: UILabel!

    @IBOutlet private weak var alignmentCell: UITableViewCell!
    @IBOutlet private weak var alignmentTitle: UILabel!
    @IBOutlet private weak var alignmentLabel: UILabel!

    @IBOutlet private weak var styleCell: UITableViewCell!
    @IBOutlet private weak var styleTitle: UILabel!
    @IBOutlet private weak var styleLabel: UILabel!

    @IBOutlet private weak var fontFamiliesCell: UITableViewCell!
    @IBOutlet private weak var fontFamiliesTitle: UILabel!
    @IBOutlet private weak var fontFamiliesLabel: UILabel!

    @IBOutlet private weak var sizeCell: UITableViewCell!
    @IBOutlet private weak var sizeTitle: UILabel!
    @IBOutlet private weak var sizeLabel: UILabel!

    @IBOutlet private weak var colorCell: UITableViewCell!
    @IBOutlet private weak var colorTitle: UILabel!
    @IBOutlet private weak var colorLabel: UILabel!

    func setCellTheme() {
        textCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        textTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        textLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        alignmentCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        alignmentTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        alignmentLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        styleCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        styleTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        styleLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        fontFamiliesCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        fontFamiliesTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        fontFamiliesLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        sizeCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        sizeTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        sizeLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText

        colorCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        colorTitle.textColor = ThemeManager.shared.currentTheme.PrimaryText
        colorLabel.textColor = ThemeManager.shared.currentTheme.SecondaryText
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshView()
        setCellTheme()
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
        @unknown default:
            alignmentLabel.text = "ua_textinfo_alignment_unknown".localized()
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
