/* Copyright Airship and Contributors */

import Foundation

@objc(UAThomasDelegate)
public protocol ThomasDelegate {
    func onFormResult(formIdentifier: String, formData: [String : Any])
    func onButtonTap(buttonIdentifier: String)
    func onDismiss(buttonIdentifier: String?, cancel: Bool)
    func onTimedOut()
    func onPageView(pagerIdentifier: String, pageIndex: Int, pageCount: Int)
}
