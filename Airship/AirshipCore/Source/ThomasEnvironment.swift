/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasEnvironment : ObservableObject {
    private let delegate: ThomasDelegate
    let actionRunner: ActionRunnerProtocol = ThomasActionRunner()
    let extensions: ThomasExtensions?
    let imageLoader: ImageLoader;
    
    var isDismissed = false
    private var onDismiss: (() -> Void)

    init(delegate: ThomasDelegate,
         extensions: ThomasExtensions?,
         onDismiss: @escaping () -> Void) {
        self.delegate = delegate
        self.extensions = extensions
        self.onDismiss = onDismiss
        self.imageLoader = ImageLoader(imageProvider: extensions?.imageProvider)
    }
    
    func submitForm(_ formState: FormState, layoutState: LayoutState) {
        if let data = formState.data.toPayload() {
            let layoutStatePayload = layoutState.toPayload()
            AirshipLogger.debug("onFormSubmitted \(formState.identifier) formData: \(data) layoutState: \(layoutStatePayload)")
            self.delegate.onFormSubmitted(formIdentifier: formState.identifier, formData: data, layoutState: layoutStatePayload)
        }
        
        Airship.channel.editAttributes { channelEditor in
            Airship.contact.editAttributes { contactEditor in
                for (attributeName, attributeValue) in formState.attributes {
                    if let channelAttribute = attributeName.channel {
                        switch (attributeValue) {
                    
                        case .string(let value):
                            channelEditor.set(string: value, attribute: channelAttribute)
                            
                        case .number(let value):
                            channelEditor.set(number: NSNumber(value:value), attribute: channelAttribute)
                        }
                    } else if let contactAttribute = attributeName.contact {
                        switch (attributeValue) {
                     
                        case .string(let value):
                            contactEditor.set(string: value, attribute: contactAttribute)
                    
                        case .number(let value):
                            contactEditor.set(number: NSNumber(value:value), attribute: contactAttribute)
                        }
                    }
                }
                contactEditor.apply()
            }
            channelEditor.apply()
        }
    }
    
    func formDisplayed(_ formIdentifier: String, layoutState: LayoutState) {
        let layoutStatePayload = layoutState.toPayload()
        AirshipLogger.debug("onFormDisplayed \(formIdentifier) layoutState: \(layoutStatePayload)")
        self.delegate.onFormDisplayed(formIdentifier: formIdentifier, layoutState: layoutStatePayload)
    }
        
    func buttonTapped(buttonIdentifier: String, layoutState: LayoutState) {
        let layoutStatePayload = layoutState.toPayload()
        AirshipLogger.debug("onButtonTapped \(buttonIdentifier) layoutState: \(layoutStatePayload)")
        self.delegate.onButtonTapped(buttonIdentifier: buttonIdentifier, layoutState: layoutStatePayload)
    }
    
    func pageViewed(pageState: PagerState, layoutState: LayoutState) {
        let layoutStatePayload = layoutState.toPayload()
        AirshipLogger.debug("onPageViewed \(pageState.identifier) pageIndex: \(pageState.index) pageCount: \(pageState.pages) completed: \(pageState.completed) layoutState: \(layoutStatePayload)")
        self.delegate.onPageViewed(pagerIdentifier: pageState.identifier,
                                   pageIndex: pageState.index,
                                   pageCount: pageState.pages,
                                   completed: pageState.completed,
                                   layoutState: layoutStatePayload)
    }
    
    
    func dismiss(buttonIdentifier: String, buttonDescription: String?, cancel: Bool, layoutState: LayoutState) {
        tryDismiss {
            let layoutStatePayload = layoutState.toPayload()
            AirshipLogger.debug("onDismissed buttonIdentifier: \(buttonIdentifier) buttonDescription: \(buttonDescription ?? "") layoutState: \(layoutStatePayload)")
            self.delegate.onDismissed(layoutState: layoutStatePayload)
        }
    }
    
    func dismiss(layoutState: LayoutState? = nil) {
        tryDismiss {
            let layoutStatePayload = layoutState?.toPayload() ?? [:]
            AirshipLogger.debug("onDismissed layoutState: \(layoutStatePayload)")
            self.delegate.onDismissed(layoutState: layoutStatePayload)
        }
    }
    
    func timedOut(layoutState: LayoutState? = nil) {
        tryDismiss {
            let layoutStatePayload = layoutState?.toPayload() ?? [:]
            AirshipLogger.debug("onTimedOut layoutState: \(layoutStatePayload)")
            self.delegate.onTimedOut(layoutState: layoutStatePayload)
        }
    }
    
    func pageSwiped(_ pagerIdentifier: String, fromIndex: Int, toIndex: Int, layoutState: LayoutState) {
        let layoutStatePayload = layoutState.toPayload()
        AirshipLogger.debug("onPageSwiped \(pagerIdentifier) fromIndex: \(fromIndex) toIndex: \(toIndex) layoutState: \(layoutStatePayload)")
        self.delegate.onPageSwiped(pagerIdentifier: pagerIdentifier, fromIndex: fromIndex, toIndex: toIndex, layoutState: layoutStatePayload)
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
private extension LayoutState {
    func toPayload() -> [String: Any] {
        var payload: [String: Any] = [:]
        if let pagerState = pagerState {
            payload["pager"] = [
                "identifier": pagerState.identifier,
                "index": pagerState.index,
                "completed": pagerState.completed,
                "count": pagerState.pages
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
