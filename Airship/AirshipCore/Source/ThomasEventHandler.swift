/* Copyright Airship and Contributors */

import Foundation

protocol ThomasEventHandler : AnyObject {
    func onFormResult(formIdentifier: String, formData: FormInputData)
    func onRunActions(actions: [String: Any])
    func onButtonTap(buttonIdentifier: String)
    func onDismiss(buttonIdentifier: String)
    func onCancel(buttonIdentifier: String)
    func onPageView(pagerIdentifier: String, pageIndex: Int, pageCount: Int)
}
