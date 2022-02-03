import UIKit

class PreferenceCenterCheckBox: UIButton {
    var callback : ((Bool, [String])->())?
    var scopes: [String] = []
    let boxCheckedImage = UIImage(named: "green_checked_circle.png", in:Bundle(identifier: "com.urbanairship.AirshipPreferenceCenter"), compatibleWith: nil)
    let boxUncheckedImage = UIImage(named: "empty_circle.png", in:Bundle(identifier: "com.urbanairship.AirshipPreferenceCenter"), compatibleWith: nil)

    var isChecked: Bool = false {
        didSet {
            if isChecked == true {
                self.setImage(boxCheckedImage, for: UIControl.State.normal)
            } else {
                self.setImage(boxUncheckedImage, for: UIControl.State.normal)
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addTarget(self, action:#selector(buttonClicked(sender:)), for: UIControl.Event.touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            isChecked = !isChecked
            callback?(isChecked, scopes)
        }
    }
}
