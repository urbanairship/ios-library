/* Copyright Airship and Contributors */

import UIKit


fileprivate enum Sections : Int, CaseIterable {
    case Identifier = 0
    case PropertyType = 1
    case Value = 2
}

fileprivate enum TextFieldTags : Int {
    case identifier = 0
    case number = 1
    case string = 2
}

class CustomPropertyAdderTableViewController: UITableViewController, UITextViewDelegate, UITextFieldDelegate {

    var pendingProperty:PendingProperty!
    var processingTask:DispatchWorkItem?

    @IBOutlet var doneButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = true

        setTableViewTheme()

        // Initialize new property to false boolean
        if (pendingProperty.type == nil && pendingProperty.value == nil) {
            pendingProperty.type = .boolean
            pendingProperty.value = false
        }
    }

    func setTableViewTheme() {
        self.tableView.backgroundColor = ThemeManager.shared.currentTheme.SecondaryBackground
    }

    @IBAction func doneButtonTapped(_ sender: Any) {
        addProperties()
        self.navigationController?.popViewController(animated: true)
    }

    func addProperties() {
        guard let pendingProperty = pendingProperty,
            pendingProperty.identifier != "",
            pendingProperty.value != nil else {
                displayMessage("ua_custom_event_add_error".localized())
                return
        }

        let customEventTVC = self.navigationController?.viewControllers[0] as! CustomEventTableViewController

        let pendingProperties = customEventTVC.pendingProperties

        // Remove previously specified values under this identifier
        if pendingProperties.contains(where: { $0.identifier == pendingProperty.identifier }) {
            customEventTVC.pendingProperties.removeAll{$0.identifier == pendingProperty.identifier}
        }

        customEventTVC.pendingProperties.append(pendingProperty)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case Sections.Identifier.rawValue:
            return configureIdentifierCell(tableView: tableView, indexPath: indexPath)
        case Sections.PropertyType.rawValue: // Type segmented control cell
            let cell = configureTypeCell(tableView: tableView, indexPath: indexPath)
            return cell
        case Sections.Value.rawValue: // Value field cell
            switch pendingProperty.type {
            case .boolean:
                return configureBoolCell(tableView: tableView, indexPath: indexPath)
            case .number:
                return configureNumberCell(tableView: tableView, indexPath: indexPath)
            case .string:
                return configureStringCell(tableView: tableView, indexPath: indexPath)
            case .json:
                return configureJSONCell(tableView: tableView, indexPath: indexPath)
            default:
                break
            }
        default:
            break
        }

        return UITableViewCell()
    }

    // MARK : Cell Configuration

    private func configureTypeCell(tableView:UITableView, indexPath: IndexPath) -> PropertyTypeCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PropertyTypeCell.reuseIdentifier, for: indexPath) as! PropertyTypeCell

        // Initialize segment state
        if (pendingProperty.type != nil) {
            cell.typeControl.selectedSegmentIndex = pendingProperty.type!.rawValue
        } else {
            pendingProperty.type = cell.typeControl.selectedSegmentIndex.segmentIndexToType()
        }
        cell.typeControl.addTarget(self, action: #selector(typeChanged), for: .valueChanged)

        return cell
    }

    private func configureIdentifierCell(tableView:UITableView, indexPath: IndexPath) -> PropertyIdentifierCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PropertyIdentifierCell.reuseIdentifier, for: indexPath) as! PropertyIdentifierCell

        // Initialization sync
        if ((cell.textField.text == nil || cell.textField.text == "") && pendingProperty.identifier != nil) {
            cell.textField.text = pendingProperty.identifier
        }

        cell.textField.delegate = self
        cell.textField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.textField.backgroundColor = ThemeManager.shared.currentTheme.Background
        cell.textField.attributedPlaceholder = NSAttributedString(string: "ua_required".localized(), attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.SecondaryText])

        return cell
    }

    private func configureBoolCell(tableView:UITableView, indexPath: IndexPath) -> PropertyBoolCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PropertyBoolCell.reuseIdentifier, for: indexPath) as! PropertyBoolCell

        cell.booleanSegmentedControl.addTarget(self, action: #selector(boolChanged), for: .valueChanged)

        // Initialization sync
        if let boolProperty = pendingProperty.value as? Bool {
            cell.booleanSegmentedControl.selectedSegmentIndex = boolProperty ? 1 : 0
        }

        return cell
    }

    private func configureNumberCell(tableView:UITableView, indexPath: IndexPath) -> PropertyNumberCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PropertyNumberCell.reuseIdentifier, for: indexPath) as! PropertyNumberCell

        // Initialization sync
        if let numberProperty = pendingProperty.value as? NSNumber {
            cell.numberField.text = "\(numberProperty)"
        }

        cell.numberField.delegate = self
        cell.numberField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.numberField.backgroundColor = ThemeManager.shared.currentTheme.Background
        cell.numberField.attributedPlaceholder = NSAttributedString(string: "ua_required".localized(), attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.SecondaryText])

        return cell
    }

    private func configureStringCell(tableView:UITableView, indexPath: IndexPath) -> PropertyStringCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PropertyStringCell.reuseIdentifier, for: indexPath) as! PropertyStringCell

        // Initialization sync
        if let stringProperty = pendingProperty.value as? String {
            cell.stringField.text = stringProperty
        }

        cell.stringField.delegate = self
        cell.stringField.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.stringField.backgroundColor = ThemeManager.shared.currentTheme.Background

        cell.stringField.attributedPlaceholder = NSAttributedString(string: "ua_required".localized(), attributes: [NSAttributedString.Key.foregroundColor: ThemeManager.shared.currentTheme.SecondaryText])

        return cell
    }

    private func configureJSONCell(tableView:UITableView, indexPath: IndexPath) -> PropertyJSONCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PropertyJSONCell.reuseIdentifier, for: indexPath) as! PropertyJSONCell

        // Initialization sync
        if let jsonProperty = pendingProperty.value as? String {
            cell.multilineTextView.text = jsonProperty
        }

        cell.multilineTextView.delegate = self
        cell.multilineTextView.textColor = ThemeManager.shared.currentTheme.PrimaryText
        cell.multilineTextView.backgroundColor = ThemeManager.shared.currentTheme.Background

        return cell
    }

    // MARK: - Segment control changes

    @objc func typeChanged(sender:UISegmentedControl) {
        pendingProperty.value = nil
        pendingProperty.type = nil

        // Initialize boolean to false on type switch to boolean
        if (sender.selectedSegmentIndex.segmentIndexToType() == .boolean) {
            pendingProperty.value = false
        }

        animatedReload()
    }

    @objc func boolChanged(sender:UISegmentedControl) {
        pendingProperty.value = sender.selectedSegmentIndex == 0 ? false : true
        animatedReload()
    }

    private func animatedReload() {
        UIView.transition(with: tableView,
                          duration: 0.35,
                          options: .transitionCrossDissolve,
                          animations: { self.tableView.reloadData() })
    }

    // MARK: Input Processing

    func processIdentifierField(_ textField: UITextField) {
        var valid:Bool = false
        defer { textField.applyCupertinoBorder(valid ? #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1) : #colorLiteral(red: 1, green: 0, blue: 0.1848241687, alpha: 1) ) }

        guard let text = textField.text,
            validateStringInput(input: text) else {
                return
        }

        valid = true
        pendingProperty.identifier = text
    }

    func processNumberField(_ textField: UITextField) {
        var valid:Bool = false
        defer { textField.applyCupertinoBorder(valid ? #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1) : #colorLiteral(red: 1, green: 0, blue: 0.1848241687, alpha: 1) ) }

        guard let text = textField.text,
            validateNumberInput(input:text) else {
                return
        }

        valid = true
        pendingProperty.value = NSDecimalNumber(string: text)
    }

    func processStringField(_ textField: UITextField) {
        var valid:Bool = false
        defer { textField.applyCupertinoBorder(valid ? #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1) : #colorLiteral(red: 1, green: 0, blue: 0.1848241687, alpha: 1) ) }

        guard let text = textField.text, validateStringInput(input:text) else {
            return
        }

        valid = true
        pendingProperty.value = text
    }

    func processTextView(_ textView: UITextView) {
        var valid:Bool = false
        defer { textView.applyCupertinoBorder(valid ?  #colorLiteral(red: 0, green: 0.2950756848, blue: 0.9987069964, alpha: 1) : #colorLiteral(red: 1, green: 0, blue: 0.1848241687, alpha: 1) ) }

        guard validateJSONInput(input: textView.text) else {
            return
        }

        valid = true
        pendingProperty.value = textView.text.prettyJSONFormat()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        performWithDebounce(workItem: DispatchWorkItem(block: {
            switch textField.tag {
            case TextFieldTags.identifier.rawValue:
                self.processIdentifierField(textField)
                break
            case TextFieldTags.number.rawValue:
                self.processNumberField(textField)
                break
            case TextFieldTags.string.rawValue:
                self.processStringField(textField)
                break
            default:
                break
            }
        }));

        return true
    }

    // MARK: Text View Delegate

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        performWithDebounce(workItem: DispatchWorkItem(block: {
            self.processTextView(textView)
        }));

        return true
    }

    // MARK: Validation

    func validateNumberInput(input:String?) -> Bool {
        guard let input = input else { return false }

        if !input.isNumeric() || input.isEmpty {
            return false
        }

        return true
    }

    func validateStringInput(input:String?) -> Bool {
        guard let input = input else { return false }

        return !input.isEmpty
    }

    func validateJSONInput(input:String?) -> Bool {
        return input!.prettyJSONFormat() != nil && validateStringInput(input: input)
    }

    func performWithDebounce(workItem:DispatchWorkItem) {
        processingTask?.cancel()

        processingTask = workItem

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1, execute: processingTask!)
    }

    func displayMessage (_ messageString: String) {
        let alertController = UIAlertController(title: "ua_alert_title_notice".localized(), message: messageString, preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: "ua_alert_ok".localized(), style: .cancel, handler: nil)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}
