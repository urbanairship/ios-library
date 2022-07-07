/* Copyright Airship and Contributors */

import Foundation

@available(iOS 13.0.0, tvOS 13.0, *)
class ThomasEnvironment : ObservableObject {
    private let delegate: ThomasDelegate
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
        if let formResult = formState.toFormResult() {
            self.delegate.onFormSubmitted(formResult: formResult,
                                          layoutContext: layoutState.toLayoutContext())
        }
        
        let channelEditor = Airship.channel.editAttributes()
        let contactEditor = Airship.contact.editAttributes()
        
        formState.data.attributes().forEach {
            let attributeName = $0.0
            let attributeValue = $0.1
            
            if let attribute = attributeName.channel {
                channelEditor.set(attributeValue: attributeValue, attribute: attribute)
            }
            
            if let attribute = attributeName.contact {
                contactEditor.set(attributeValue: attributeValue, attribute: attribute)
            }
        }
        
        channelEditor.apply()
        contactEditor.apply()
    }
    
    
    func formDisplayed(_ formState: FormState, layoutState: LayoutState) {
        self.delegate.onFormDisplayed(formInfo: formState.toFormInfo(),
                                      layoutContext: layoutState.toLayoutContext())
    }
        
    func buttonTapped(buttonIdentifier: String, layoutState: LayoutState) {
        self.delegate.onButtonTapped(buttonIdentifier: buttonIdentifier,
                                     layoutContext: layoutState.toLayoutContext())
    }
    
    func pageViewed(_ pagerState: PagerState, layoutState: LayoutState) {
        self.delegate.onPageViewed(pagerInfo: pagerState.toPagerInfo(),
                                   layoutContext: layoutState.toLayoutContext())
    }

    func dismiss(buttonIdentifier: String, buttonDescription: String, cancel: Bool, layoutState: LayoutState) {
        tryDismiss {
            self.delegate.onDismissed(buttonIdentifier: buttonIdentifier,
                                      buttonDescription: buttonDescription,
                                      cancel: cancel,
                                      layoutContext: layoutState.toLayoutContext())
        }
    }
    
    func dismiss(layoutState: LayoutState? = nil) {
        tryDismiss {
            self.delegate.onDismissed(layoutContext: layoutState?.toLayoutContext())
        }
    }
    
    func timedOut(layoutState: LayoutState? = nil) {
        tryDismiss {
            self.delegate.onTimedOut(layoutContext: layoutState?.toLayoutContext())
        }
    }
    
    func pageSwiped(_ pagerState: PagerState, fromIndex: Int, toIndex: Int, layoutState: LayoutState) {
        self.delegate.onPageSwiped(from: pagerState.toPagerInfo(index: fromIndex),
                                   to: pagerState.toPagerInfo(index: toIndex),
                                   layoutContext: layoutState.toLayoutContext())
    }
    
    private func tryDismiss(callback: () -> Void) {
        if (!self.isDismissed) {
            self.isDismissed = true
            callback()
            onDismiss()
        }
    }

    func runActions(_ actionsPayload: ActionsPayload?, layoutState: LayoutState) {
        guard let actionsPayload = actionsPayload else {
            return
        }

        guard let actionValues = actionsPayload.value.unWrap() as? [String : Any] else {
            AirshipLogger.error("Invalid actions payload: \(actionsPayload)")
            return
        }

        self.delegate.onRunActions(actions: actionValues,
                                   layoutContext: layoutState.toLayoutContext())
    }
}

enum DismissReason {
    case button(String, Bool)
    case timedOut
    case other
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension FormState {
    func toFormInfo() -> ThomasFormInfo {
        ThomasFormInfo(identifier: self.identifier,
                       submitted: self.isSubmitted,
                       formType: self.formTypeString,
                       formResponseType: self.formResponseType)
    }
    
    var formTypeString: String {
        switch self.formType {
        case .form:
            return "form"
        case .nps(_):
            return "nps"
        }
    }
    
    func toFormResult() -> ThomasFormResult? {
        if let data = self.data.toPayload() {
            return ThomasFormResult(identifier: self.identifier,
                                    formData: data)
        }
        return nil
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension PagerState {
    func toPagerInfo(index: Int? = nil) -> ThomasPagerInfo {
        let index = index ?? self.pageIndex
        var pageId: String = ""
        if (index < self.pages.count) {
            pageId = self.pages[index]
        }
        
        return ThomasPagerInfo(identifier: self.identifier,
                               pageIndex: index,
                               pageIdentifier: pageId,
                               pageCount: self.pages.count,
                               completed: self.completed)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension ButtonState {
    func toButtonInfo() -> ThomasButtonInfo {
        return ThomasButtonInfo(identifier: self.identifier)
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension LayoutState {
    func toLayoutContext() -> ThomasLayoutContext {
        ThomasLayoutContext(formInfo: self.formState?.toFormInfo(),
                            pagerInfo: self.pagerState?.toPagerInfo(),
                            buttonInfo: self.buttonState?.toButtonInfo())
    }
}

@available(iOS 13.0.0, tvOS 13.0, *)
private extension AttributesEditor {
    func set(attributeValue: AttributeValue, attribute: String) {
        switch (attributeValue) {
        case .string(let value):
            self.set(string: value, attribute: attribute)
            
        case .number(let value):
            self.set(double: value, attribute: attribute)
        }
    }
}
