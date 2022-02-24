/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#endif

class PreferenceCenterCheckbox: UIButton {
    private let callback: (Bool)->()
    private let component: ContactSubscriptionGroupItem.Component

    private let checkedImage: UIImage
    private let uncheckedImage: UIImage
    
    private static let spacing = 4.0

    var isChecked: Bool = false {
        didSet {
            if isChecked {
                self.setImage(checkedImage, for: UIControl.State.normal)
            } else {
                self.setImage(uncheckedImage, for: UIControl.State.normal)
            }
        }
    }

    init(component: ContactSubscriptionGroupItem.Component,
         checkedImage: UIImage,
         uncheckedImage: UIImage,
         callback: @escaping (Bool)->()) {
        self.component = component
        self.callback = callback
        self.checkedImage = checkedImage
        self.uncheckedImage = uncheckedImage

        super.init(frame: .zero)
        self.addTarget(self, action:#selector(buttonClicked(sender:)), for: UIControl.Event.touchUpInside)
        self.setTitle(component.display.title, for: .normal)
        
        // Since we have 5x spacing - space<image>space space<text>space space, we need to move
        // the image over 1.5*spacing to the left and the title .5*spacing to the right
        
        self.titleEdgeInsets = UIEdgeInsets(top: 0,
                                            left: PreferenceCenterCheckbox.spacing * 0.5,
                                            bottom: 0,
                                            right: 0)
        
        self.imageEdgeInsets = UIEdgeInsets(top: 0,
                                            left: -(PreferenceCenterCheckbox.spacing * 1.5),
                                            bottom: 0,
                                            right: 0)
        self.layer.borderWidth = 1
        self.clipsToBounds = true
        self.layer.cornerRadius = self.intrinsicContentSize.height / 2
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .circular
        }
    }

    override var intrinsicContentSize: CGSize {
        let imageSize = self.uncheckedImage.size
        let labelSize = titleLabel?.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                        height: CGFloat.greatestFiniteMagnitude)) ?? .zero
        
        // space<image>space space<text>space space
        let horizontalSpacing = PreferenceCenterCheckbox.spacing * 5
        
        // Top + Bottom
        let verticalSpacing = PreferenceCenterCheckbox.spacing * 2
        
        return CGSize(width: labelSize.width + imageSize.width + horizontalSpacing,
                      height: max(imageSize.height, labelSize.height) + verticalSpacing)
     }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func buttonClicked(sender: UIButton) {
        if sender == self {
            isChecked.toggle()
            callback(isChecked)
        }
    }
}
