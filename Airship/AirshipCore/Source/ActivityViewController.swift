/* Copyright Airship and Contributors */

import UIKit

#if os(iOS)
@objc(UAActivityViewController)
public class ActivityViewController :  UIActivityViewController, UIPopoverPresentationControllerDelegate, UIPopoverControllerDelegate {
    
    @objc
    public var dismissalBlock: (() -> Void)?
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        dismissalBlock?()
    }

    /**
     * Returns the desired source rect dimensions for the popover.
     * - Returns: popover diminsions.
     */
    @objc
    public func sourceRect() -> CGRect {
        let windowBounds = Utils.mainWindow()?.bounds

        // Return a smaller rectangle by 25% on each axis, producing a 50% smaller rectangle inset.
        return windowBounds?.insetBy(dx: (windowBounds?.width ?? 0.0) / 4.0, dy: (windowBounds?.height ?? 0.0) / 4.0) ?? CGRect.zero
    }
    
    public func popoverPresentationController(_ popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>, in view: AutoreleasingUnsafeMutablePointer<UIView>) {
        rect.pointee = sourceRect()
    }
}
#endif
