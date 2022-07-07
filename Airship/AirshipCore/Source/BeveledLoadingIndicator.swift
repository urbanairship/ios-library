/* Copyright Airship and Contributors */

import UIKit
#if !os(watchOS)
import QuartzCore

/**
 * An abstraction around a nicer looking
 * loading indicator that embeds a UIActivityIndicatorView
 * in a translucent black beveled rect.
 */
@objc(UABeveledLoadingIndicator)
public class BeveledLoadingIndicator : UIView {
    private var activity: UIActivityIndicatorView?

    @objc
    override open var isHidden: Bool {
        didSet {
            if isHidden {
                activity?.stopAnimating()
            } else {
                activity?.startAnimating()
            }
        }
    }

    @objc
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    @objc
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        self.isHidden = false
    }

    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black
        alpha = 0.7
        layer.cornerRadius = 10.0
        isHidden = true

        activity = UIActivityIndicatorView(style: .whiteLarge)
        activity?.hidesWhenStopped = true
        activity?.translatesAutoresizingMaskIntoConstraints = false

        addSubview(activity!)

        var xConstraint: NSLayoutConstraint? = nil
        if let activity = activity {
            xConstraint = NSLayoutConstraint(item: activity, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0)
        }
        var yConstraint: NSLayoutConstraint? = nil
        if let activity = activity {
            yConstraint = NSLayoutConstraint(item: activity, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0)
        }

        xConstraint?.isActive = true
        yConstraint?.isActive = true
    }

    public override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    /**
     * Show and animate the indicator
     */
    @objc
    public func show() {
        isHidden = false
    }

    /**
     * Hide the indicator.
     */
    @objc
    public func hide() {
        isHidden = true
    }
}

#endif
