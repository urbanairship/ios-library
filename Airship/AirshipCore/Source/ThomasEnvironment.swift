/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasEnvironment : ObservableObject {
    private let delegate: ThomasDelegate
    let actionRunner: ActionRunnerProtocol = ThomasActionRunner()
    
    var isDismissed = false
    private var onDismiss: (() -> Void)

    init(delegate: ThomasDelegate, onDismiss: @escaping () -> Void) {
        self.delegate = delegate
        self.onDismiss = onDismiss
    }
    
    func displayed(reportingContext: ReportingContext) {
        let reportingContextPayload = reportingContext.toPayload()
        AirshipLogger.debug("onDisplayed reportingContext: \(reportingContextPayload)")
        self.delegate.onDisplayed(reportingContext: reportingContextPayload)
    }
    
    func submitForm(_ formState: FormState, reportingContext: ReportingContext) {
        if let data = formState.data.toPayload() {
            let reportingContextPayload = reportingContext.toPayload()
            AirshipLogger.debug("onFormSubmitted \(formState.identifier) formData: \(data) reportingContext: \(reportingContextPayload)")
            self.delegate.onFormSubmitted(formIdentifier: formState.identifier, formData: data, reportingContext: reportingContextPayload)
        }
    }
    
    func formDisplayed(_ formIdentifier: String, reportingContext: ReportingContext) {
        let reportingContextPayload = reportingContext.toPayload()
        AirshipLogger.debug("onFormDisplayed \(formIdentifier) reportingContext: \(reportingContextPayload)")
        self.delegate.onFormDisplayed(formIdentifier: formIdentifier, reportingContext: reportingContextPayload)
    }
        
    func buttonTapped(buttonIdentifier: String, reportingContext: ReportingContext) {
        let reportingContextPayload = reportingContext.toPayload()
        AirshipLogger.debug("onButtonTapped \(buttonIdentifier) reportingContext: \(reportingContextPayload)")
        self.delegate.onButtonTapped(buttonIdentifier: buttonIdentifier, reportingContext: reportingContextPayload)
    }
    
    func pageViewed(pageState: PagerState, reportingContext: ReportingContext) {
        let reportingContextPayload = reportingContext.toPayload()
        AirshipLogger.debug("onPageViewed \(pageState.identifier) pageIndex: \(pageState.index) pageCount: \(pageState.pages) completed: \(pageState.completed) reportingContext: \(reportingContextPayload)")
        self.delegate.onPageViewed(pagerIdentifier: pageState.identifier,
                                   pageIndex: pageState.index,
                                   pageCount: pageState.pages,
                                   completed: pageState.completed,
                                   reportingContext: reportingContextPayload)
    }
    
    
    func dismiss(buttonIdentifier: String, buttonDescription: String?, cancel: Bool, reportingContext: ReportingContext? = nil) {
        tryDismiss {
            let reportingContextPayload = reportingContext?.toPayload() ?? [:]
            AirshipLogger.debug("onDismissed buttonIdentifier: \(buttonIdentifier) buttonDescription: \(buttonDescription ?? "") reportingContext: \(reportingContextPayload)")
            self.delegate.onDismissed(reportingContext: reportingContextPayload)
        }
    }
    
    func dismiss(reportingContext: ReportingContext? = nil) {
        tryDismiss {
            let reportingContextPayload = reportingContext?.toPayload() ?? [:]
            AirshipLogger.debug("onDismissed reportingContext: \(reportingContextPayload)")
            self.delegate.onDismissed(reportingContext: reportingContextPayload)
        }
    }
    
    func timedOut(reportingContext: ReportingContext? = nil) {
        tryDismiss {
            let reportingContextPayload = reportingContext?.toPayload() ?? [:]
            AirshipLogger.debug("onTimedOut reportingContext: \(reportingContextPayload)")
            self.delegate.onTimedOut(reportingContext: reportingContextPayload)
        }
    }
    
    func pageSwiped(_ pagerIdentifier: String, fromIndex: Int, toIndex: Int, reportingContext: ReportingContext) {
        let reportingContextPayload = reportingContext.toPayload()
        AirshipLogger.debug("onPageSwiped \(pagerIdentifier) fromIndex: \(fromIndex) toIndex: \(toIndex) reportingContext: \(reportingContextPayload)")
        self.delegate.onPageSwiped(pagerIdentifier: pagerIdentifier, fromIndex: fromIndex, toIndex: toIndex, reportingContext: reportingContextPayload)
    }
    
    private func tryDismiss(callback: () -> Void) {
        if (!self.isDismissed) {
            self.isDismissed = true
            callback()
            onDismiss()
        }
    }
        
}

enum DismissReason {
    case button(String, Bool)
    case timedOut
    case other
}

private extension FormValue {
    var typeName: String {
        switch(self) {
        case .checkbox(_):
            return "checkbox"
        case .radio(_):
            return "single_choice"
        case .multipleCheckbox(_):
            return "multiple_choice"
        case .form(_):
            return "form"
        case .nps(_, _):
            return "nps"
        case .text(_):
            return "text"
        case .score(_):
            return "score"
        }
    }
}

private extension FormInputData {
    private static let typeKey = "type"
    private static let valueKey = "value"
    private static let childrenKey = "children"
    private static let scoreIdKey = "score_id"
    
    func toPayload() -> [String: Any]? {
        switch(self.value) {
        case .checkbox(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .radio(let value):
            guard let value = value else {
                return nil
            }
            
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .multipleCheckbox(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .text(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .score(let value):
            guard let value = value else {
                return nil
            }
            return [
                FormInputData.typeKey: self.value.typeName,
                FormInputData.valueKey: value
            ]
        case .form(let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { key, value in
                childrenMap[key] = value.toPayload()
            }
            
            guard !childrenMap.isEmpty else {
                return nil
            }
            return [
                FormInputData.valueKey: self.value.typeName,
                FormInputData.childrenKey: childrenMap
            ]
        case .nps(let identifier, let value):
            var childrenMap: [String: Any] = [:]
            value.forEach { key, value in
                childrenMap[key] = value.toPayload()
            }
            guard !childrenMap.isEmpty else {
                return nil
            }
            return [
                FormInputData.valueKey: self.value.typeName,
                FormInputData.scoreIdKey: identifier,
                FormInputData.childrenKey: childrenMap
            ]
        }
        
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension ReportingContext {
    func toPayload() -> [String: Any] {
        var payload: [String: Any] = [:]
        if let layoutContext = layoutContext {
            payload["reporting_context"] = layoutContext.unWrap()
        }
        
        if let pagerState = pagerState {
            payload["pager"] = [
                "identifier": pagerState.identifier,
                "index": pagerState.index,
                "completed": pagerState.completed
            ]
        }
        
        if let formState = formState {
            payload["form"] =  [
                "identifier": formState.identifier
            ]
        }
        
        return payload
    }
}
