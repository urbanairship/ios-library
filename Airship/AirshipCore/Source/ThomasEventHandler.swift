/* Copyright Airship and Contributors */

import Foundation

public protocol ThomasEventHandler : AnyObject {
    func onFormResult(formIdentifier: String, formData: [String : Any])
    func onRunActions(actions: [String: Any])
    func onButtonTap(buttonIdentifier: String)
    func onDismiss(buttonIdentifier: String)
    func onCancel(buttonIdentifier: String)
    func onDismiss()
    func onPageView(pagerIdentifier: String, pageIndex: Int, pageCount: Int)
}
