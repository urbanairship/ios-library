/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(Airship)
import Airship
#endif

class AddTagGroupsTableViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet var addTagCell: UITableViewCell!
    @IBOutlet private weak var addTagTextField: UITextField!
    
    @IBOutlet var addTagGroupCell: UITableViewCell!
    @IBOutlet private weak var addTagGroupTextField: UITextField!
    
    @IBOutlet var tagGroupActionControl: UISegmentedControl!
    @IBOutlet var tagGroupTypeControl: UISegmentedControl!
    
    var isRemove:Bool = false
    var isNamedUser:Bool = false

    var applyButton:UIBarButtonItem = UIBarButtonItem(title: "ua_tags_action_set".localized(comment: "Set"), style: .plain, target: self, action: #selector(AddTagGroupsTableViewController.updateTagGroupTag))

    override func viewDidLoad() {
        super.viewDidLoad()

        addTagTextField.delegate = self
        addTagTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        addTagGroupTextField.delegate = self
        addTagGroupTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)

        tagGroupActionControl.tintColor = ThemeManager.shared.currentTheme.WidgetTint
        tagGroupTypeControl.tintColor = ThemeManager.shared.currentTheme.WidgetTint

        var normalTitleTextAttributes : [NSAttributedString.Key : Any]?
        var selectedTitleTextAttributes : [NSAttributedString.Key : Any]?
        if #available(iOS 13, *) {
            normalTitleTextAttributes = [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.WidgetTint]
            selectedTitleTextAttributes = normalTitleTextAttributes
        } else {
            normalTitleTextAttributes = [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.WidgetTint]
            selectedTitleTextAttributes = [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.ButtonText]
        }
        tagGroupActionControl.setTitleTextAttributes(normalTitleTextAttributes, for: .normal)
        tagGroupActionControl.setTitleTextAttributes(selectedTitleTextAttributes, for: .selected)
        tagGroupTypeControl.setTitleTextAttributes(normalTitleTextAttributes, for: .normal)
        tagGroupTypeControl.setTitleTextAttributes(selectedTitleTextAttributes, for: .selected)

        tagGroupActionControl.backgroundColor = ThemeManager.shared.currentTheme.Background
        tagGroupTypeControl.backgroundColor = ThemeManager.shared.currentTheme.Background
        
        addTagCell.contentView.backgroundColor = ThemeManager.shared.currentTheme.Background
        addTagGroupCell.contentView.backgroundColor = ThemeManager.shared.currentTheme.Background

        let tapGesture = UITapGestureRecognizer(target:self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)

        applyButton.isEnabled = false
        navigationItem.rightBarButtonItem = applyButton
    }

    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        addTagTextField.resignFirstResponder()
        addTagGroupTextField.resignFirstResponder()
 
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    @objc func updateTagGroupTag() {
        guard let tagText = addTagTextField.text,
            let tagGroupText = addTagGroupTextField.text else { return }
        
        if (isRemove) {
            if (isNamedUser) {
                Airship.namedUser.removeTags([tagText], group: tagGroupText)
            } else {
                Airship.channel.removeTags([tagText], group: tagGroupText)
            }
        } else {
            if (isNamedUser) {
                Airship.namedUser.addTags([tagText], group: tagGroupText)
            } else {
                Airship.channel.addTags([tagText], group: tagGroupText)
            }
        }
        
        addTagTextField.text = ""
        addTagGroupTextField.text = ""
    }
   
    private func updateApplyButtonState() {
        isRemove ? changeNavButtonTitle("ua_tags_action_remove".localized(comment: "Remove")) : changeNavButtonTitle("ua_tags_action_set".localized(comment: "Set"))

        guard let tagText = addTagTextField.text, let tagGroupText = addTagGroupTextField.text else {
              applyButton.isEnabled = false
              return
        }

        if tagText.count == 0 {
            applyButton.isEnabled = false
            return
        }
        
        if tagGroupText.count == 0 {
            applyButton.isEnabled = false
            return
        }
               
        applyButton.isEnabled = true
           
    }

    private func setCellTheme() {
        addTagCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addTagTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addTagGroupCell.backgroundColor = ThemeManager.shared.currentTheme.Background
        addTagGroupTextField.textColor = ThemeManager.shared.currentTheme.PrimaryText

        addTagTextField.attributedPlaceholder = NSAttributedString(string:        "ua_tag_value".localized(comment: "Tag"), attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
        addTagGroupTextField.attributedPlaceholder = NSAttributedString(string:"ua_tag_group_value".localized(comment: "Tag Group"), attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
 
    }

    private func setTableViewTheme() {
        tableView.backgroundColor = ThemeManager.shared.currentTheme.Background
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setCellTheme()
        setTableViewTheme()
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.textColor = ThemeManager.shared.currentTheme.WidgetTint
        }
    }
    @IBAction func actionControlDidChange(_ sender: Any) {

        switch (tagGroupActionControl.tagGroupActionControlState()) {
         case .set:
            isRemove = false
            tableView.reloadData()
        case .remove:
            isRemove = true
            tableView.reloadData()
         }

        updateApplyButtonState()
    }
    
    @IBAction func typeControlDidChange(_ sender: Any) {

        switch (tagGroupTypeControl.tagGroupTypeControlState()) {
         case .channel:
            isNamedUser = false
            tableView.reloadData()
        case .namedUser:
            isNamedUser = true
            tableView.reloadData()
         }

        updateApplyButtonState()
    }

    func changeNavButtonTitle(_ title:String) {
        let item = navigationItem.rightBarButtonItem!
        item.title = title
        item.target = self
    }
 
    @objc func textFieldDidChange(textField: UITextField) {
        updateApplyButtonState()
        print("Text changed")
    }
}

private extension UISegmentedControl {
    enum TagGroupActionControlState {
        case set
        case remove
    }

    enum TagGroupTypeControlState {
        case channel
        case namedUser
    }

    func tagGroupTypeControlState() -> TagGroupTypeControlState {
        if selectedSegmentIndex == 0 {
            return .channel
        } else {
            return .namedUser
        }
    }

    func tagGroupActionControlState() -> TagGroupActionControlState {
        if selectedSegmentIndex == 0 {
            return .set
        } else {
            return .remove
        }
    }
    
}
