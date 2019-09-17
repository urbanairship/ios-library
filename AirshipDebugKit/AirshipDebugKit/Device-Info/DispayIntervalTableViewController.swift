/* Copyright Airship and Contributors */

import UIKit
import AirshipKit

class DispayIntervalTableViewController: UIViewController {

    @IBOutlet private weak var displayIntervalText: UILabel!
    @IBOutlet private weak var displayIntervalValue: UITextField!
    @IBOutlet private weak var displayIntervalStepper: UIStepper!
    
    let inAppAutomationDisplayIntervalKey = "inApp_automation_display_interval"
    var inAppAutomationDisplayInterval: Int {
        get {return UserDefaults.standard.integer(forKey:inAppAutomationDisplayIntervalKey)}
        set (value) {UserDefaults.standard.set(value, forKey:inAppAutomationDisplayIntervalKey)}
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func setCellTheme() {
        displayIntervalText.textColor = ThemeManager.shared.currentTheme.PrimaryText
        displayIntervalValue.textColor = ThemeManager.shared.currentTheme.PrimaryText
        displayIntervalStepper.tintColor = ThemeManager.shared.currentTheme.WidgetTint
    }

    func setTableViewTheme() {
        self.view.backgroundColor = ThemeManager.shared.currentTheme.Background;
        displayIntervalStepper.backgroundColor = ThemeManager.shared.currentTheme.Background;
        navigationController?.navigationBar.titleTextAttributes = [.foregroundColor:ThemeManager.shared.currentTheme.NavigationBarText]
        navigationController?.navigationBar.barTintColor = ThemeManager.shared.currentTheme.NavigationBarBackground;

        displayIntervalValue.attributedPlaceholder = NSAttributedString(string:"30", attributes: [NSAttributedString.Key.foregroundColor:ThemeManager.shared.currentTheme.SecondaryText])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        setCellTheme()
        setTableViewTheme()
        
        // Set stepper value
        displayIntervalValue.text = String(inAppAutomationDisplayInterval)
        displayIntervalStepper.value = Double(inAppAutomationDisplayInterval)
    }

    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        let stepperValue = Int(sender.value)
        displayIntervalValue.text = stepperValue.description
    }
    
    @IBAction func applyDisplayInterval(_ sender: Any) {
        let displayInterval = Double(displayIntervalValue.text!)!
        UAirship.inAppMessageManager().displayInterval = displayInterval
        inAppAutomationDisplayInterval = Int(displayInterval)
        
        let message = "ua_applied_interval".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
        let buttonTitle = "ua_ok".localized()
        let okAction = UIAlertAction(title: buttonTitle, style: UIAlertAction.Style.default, handler: { (action: UIAlertAction) in
            self.dismiss(animated: true, completion: nil)
            self.navigationController?.popViewController(animated: true)
        })
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
    
}
